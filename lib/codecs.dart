import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:web3dart/web3dart.dart';
import 'package:xmtp_plugin/generated/content.pb.dart';
import 'package:xmtp_plugin/generated/mls/message_contents/transcript_messages.pb.dart';
import 'package:xmtp_plugin/generated/content_types/delete_message.pb.dart' as proto_delete;
import 'package:xmtp_plugin/generated/content_types/leave_request.pb.dart' as proto_leave;
import 'package:xmtp_plugin/generated/content_types/multi_remote_attachment.pb.dart' as proto_multi;

// Export GroupUpdated for external use
export 'package:xmtp_plugin/generated/mls/message_contents/transcript_messages.pb.dart' show GroupUpdated, GroupUpdated_Inbox, GroupUpdated_MetadataFieldChange;

// Export EncodedContent protobuf for re-decoding stored messages
export 'package:xmtp_plugin/generated/content.pb.dart' show EncodedContent, ContentTypeId;

// Export protobuf-generated content types for external use
export 'package:xmtp_plugin/generated/content_types/delete_message.pb.dart' show DeleteMessage;
export 'package:xmtp_plugin/generated/content_types/leave_request.pb.dart' show LeaveRequest;
export 'package:xmtp_plugin/generated/content_types/multi_remote_attachment.pb.dart' show MultiRemoteAttachment, RemoteAttachmentInfo;

/// Base abstract class for custom codecs
abstract class XMTPCodec {
  String get authorityId;
  String get typeId;
  int get versionMajor;
  int get versionMinor;

  Future<Map<String, dynamic>> encode(dynamic content);

  // Codecs now receive EncodedContent protobuf object (like official XMTP codecs)
  // Type-safe access to: encodedContent.type, encodedContent.parameters, encodedContent.content
  Future<dynamic> decode(EncodedContent encodedContent);

  String? getFallback(dynamic content) => null;
  bool shouldPush(dynamic content) => true;
}

/// Codec registry to manage custom codecs
class XMTPCodecRegistry {
  final Map<String, XMTPCodec> _codecs = {};

  void registerCodec(XMTPCodec codec) {
    final key = '${codec.authorityId}/${codec.typeId}';
    _codecs[key] = codec;
  }

  XMTPCodec? getCodec(String authorityId, String typeId) {
    return _codecs['$authorityId/$typeId'];
  }
}

/// Text codec implementation for encoding and decoding text messages
class TextCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'text';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! String) {
      throw FormatException('Content must be String, got ${content.runtimeType}');
    }
    return {
      'content': Uint8List.fromList(utf8.encode(content)),
      'parameters': {'encoding': 'UTF-8'},
    };
  }

  @override
  Future<String> decode(EncodedContent encodedContent) async {
    try {
      return utf8.decode(encodedContent.content);
    } catch (e) {
      throw FormatException('Failed to decode text: $e');
    }
  }

  @override
  String? getFallback(dynamic content) => content as String?;
}

// ============================================================================
// Actions — JSON wire format (coinbase.com/actions/1.0)
// Bot sends a menu with tappable action buttons.
// ============================================================================

/// Decoded Actions data — a menu of interactive buttons from a bot.
class ActionsContent {
  final String id;
  final String description;
  final List<ActionItem> actions;

  const ActionsContent({
    required this.id,
    required this.description,
    required this.actions,
  });

  factory ActionsContent.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] as List?;
    final actions = <ActionItem>[];
    if (rawActions != null) {
      for (final a in rawActions) {
        if (a is Map<String, dynamic>) {
          actions.add(ActionItem.fromJson(a));
        }
      }
    }
    return ActionsContent(
      id: json['id'] as String,
      description: (json['description'] as String?) ?? '',
      actions: actions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'actions': actions.map((a) => a.toJson()).toList(),
      };
}

class ActionItem {
  final String id;
  final String label;
  final String? imageUrl;
  final String style; // "primary", "secondary", "danger"

  const ActionItem({
    required this.id,
    required this.label,
    this.imageUrl,
    this.style = 'secondary',
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) => ActionItem(
        id: json['id'] as String,
        label: json['label'] as String,
        imageUrl: json['imageUrl'] as String?,
        style: (json['style'] as String?) ?? 'secondary',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'style': style,
      };
}

/// Actions codec — coinbase.com/actions (JSON wire format)
class ActionsCodec extends XMTPCodec {
  @override
  String get authorityId => 'coinbase.com';

  @override
  String get typeId => 'actions';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! ActionsContent) {
      throw const FormatException('Content must be ActionsContent');
    }
    final jsonBytes = utf8.encode(jsonEncode(content.toJson()));
    return {
      'content': Uint8List.fromList(jsonBytes),
      'parameters': <String, String>{},
    };
  }

  @override
  Future<ActionsContent> decode(EncodedContent encodedContent) async {
    try {
      final jsonString = utf8.decode(encodedContent.content);
      final Map<String, dynamic> data = jsonDecode(jsonString);
      return ActionsContent.fromJson(data);
    } catch (e) {
      throw FormatException('Failed to decode Actions: $e');
    }
  }

  @override
  String? getFallback(dynamic content) {
    if (content is ActionsContent) {
      final buf = StringBuffer()..writeln(content.description);
      for (var i = 0; i < content.actions.length; i++) {
        buf.writeln('[${i + 1}] ${content.actions[i].label}');
      }
      buf.write('\nReply with the number to select');
      return buf.toString();
    }
    return null;
  }
}

// ============================================================================
// Intent — JSON wire format (coinbase.com/intent/1.0)
// User replies to a bot menu by selecting an action.
// ============================================================================

/// Decoded Intent data — the user's selected action in response to a bot menu.
class IntentContent {
  final String id; // References the Actions message ID
  final String actionId; // The selected action ID
  final Map<String, dynamic>? metadata;

  const IntentContent({
    required this.id,
    required this.actionId,
    this.metadata,
  });

  factory IntentContent.fromJson(Map<String, dynamic> json) =>
      IntentContent(
        id: json['id'] as String,
        actionId: json['actionId'] as String,
        metadata: json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionId': actionId,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Intent codec — coinbase.com/intent (JSON wire format)
class IntentCodec extends XMTPCodec {
  @override
  String get authorityId => 'coinbase.com';

  @override
  String get typeId => 'intent';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! IntentContent) {
      throw const FormatException('Content must be IntentContent');
    }
    final jsonBytes = utf8.encode(jsonEncode(content.toJson()));
    return {
      'content': Uint8List.fromList(jsonBytes),
      'parameters': <String, String>{},
    };
  }

  @override
  Future<IntentContent> decode(EncodedContent encodedContent) async {
    try {
      final jsonString = utf8.decode(encodedContent.content);
      final Map<String, dynamic> data = jsonDecode(jsonString);
      return IntentContent.fromJson(data);
    } catch (e) {
      throw FormatException('Failed to decode Intent: $e');
    }
  }

  @override
  String? getFallback(dynamic content) {
    if (content is IntentContent) {
      return 'User selected action: ${content.actionId}';
    }
    return null;
  }
}

/// Data class for attachment content
class AttachmentContent {
  final Uint8List data;
  final String mimeType;
  final String filename;
  final String? description;

  /// True when this attachment is a sticker (keyboard / IME insertion).
  /// Carried on the wire as the string parameter `isSticker:"true"` on the
  /// standard `xmtp.org/attachment` codec — non-PublicOS clients ignore the
  /// unknown param and still render the image. Receivers render it bubble-less.
  final bool isSticker;

  AttachmentContent({
    required this.data,
    required this.mimeType,
    required this.filename,
    this.description,
    this.isSticker = false,
  });

// In codecs.dart - Improved AttachmentContent.fromJson
  factory AttachmentContent.fromJson(Map<String, dynamic> json) {
    // Initialize with empty data as default
    Uint8List dataBytes = Uint8List(0);

    // Process data field based on its type
    if (json.containsKey('data')) {
      var data = json['data'];

      if (data is String) {
        try {
          // First try base64 decoding
          dataBytes = base64Decode(data);
        } catch (e) {
          print('Error base64 decoding data: $e');

          // If base64 fails, try hex decoding if it looks like hex
          if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(data)) {
            try {
              dataBytes = Uint8List.fromList(List<int>.generate(data.length ~/ 2, (i) => int.parse(data.substring(i * 2, i * 2 + 2), radix: 16)));
            } catch (e) {
              print('Error hex decoding data: $e');
            }
          }
        }
      } else if (data is List) {
        // Handle list of integers
        dataBytes = Uint8List.fromList(List<int>.from(data));
      } else if (data is Uint8List) {
        // Already in correct format
        dataBytes = data;
      }
    }

    return AttachmentContent(
      filename: json['filename'] as String? ?? 'attachment',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      data: dataBytes,
      description: json['description'] as String?,
      isSticker: json['isSticker'] == true || json['isSticker'] == 'true',
    );
  }

// In codecs.dart - Improved AttachmentContent.toJson
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'mimeType': mimeType,
      // Always encode binary data as base64 string for consistent storage
      'data': base64Encode(data),
      if (description != null) 'description': description,
      if (isSticker) 'isSticker': true,
    };
  }
}

/// Attachment codec implementation
class AttachmentCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'attachment';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! AttachmentContent) {
      throw const FormatException('Content must be AttachmentContent');
    }
    return {
      'content': content.data,
      'parameters': {
        'filename': content.filename,
        'mimeType': content.mimeType,
        if (content.description != null) 'description': content.description!,
        if (content.isSticker) 'isSticker': 'true',
      }
    };
  }

  @override
  Future<AttachmentContent> decode(EncodedContent encodedContent) async {
    return AttachmentContent(
      data: Uint8List.fromList(encodedContent.content),
      mimeType: encodedContent.parameters['mimeType'] ?? 'application/octet-stream',
      filename: encodedContent.parameters['filename'] ?? 'attachment',
      description: encodedContent.parameters['description'],
      isSticker: encodedContent.parameters['isSticker'] == 'true',
    );
  }

  @override
  String? getFallback(dynamic content) {
    if (content is AttachmentContent) {
      return content.isSticker
          ? '[Sticker]'
          : '[Attachment: ${content.filename}]';
    }
    return null;
  }
}

/// Content type information for messages
class ContentType {
  final String authorityId;
  final String typeId;
  final int versionMajor;

  ContentType({
    required this.authorityId,
    required this.typeId,
    required this.versionMajor,
  });

  factory ContentType.fromMap(Map<dynamic, dynamic> map) {
    return ContentType(
      authorityId: map['authorityId'] as String,
      typeId: map['typeId'] as String,
      versionMajor: map['versionMajor'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorityId': authorityId,
        'typeId': typeId,
        'versionMajor': versionMajor,
      };
}

class EncryptedEncodedContent {
  final String contentDigest;
  final Uint8List secret;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List payload;
  final int? contentLength;
  final String? filename;

  EncryptedEncodedContent({
    required this.contentDigest,
    required this.secret,
    required this.salt,
    required this.nonce,
    required this.payload,
    this.contentLength,
    this.filename,
  });
}

class RemoteAttachmentContent {
  final String url;
  final String contentDigest;
  final Uint8List secret;
  final Uint8List salt;
  final Uint8List nonce;
  final String scheme; // URL scheme — 'http' (LAN/dev) or 'https' (production)
  final int contentLength;
  final String filename;
  final String? description; // Optional description — travels via XMTP, not stored on server

  RemoteAttachmentContent({
    required this.url,
    required this.contentDigest,
    required this.secret,
    required this.salt,
    required this.nonce,
    required this.scheme,
    required this.contentLength,
    required this.filename,
    this.description,
  });

  /// Factory constructor with validation to ensure XMTP spec compliance
  factory RemoteAttachmentContent.create({
    required String url,
    required String contentDigest,
    required Uint8List secret,
    required Uint8List salt,
    required Uint8List nonce,
    required int contentLength,
    required String filename,
    String? description,
  }) {
    // Validate URL scheme — accept http (LAN/dev) and https (production)
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw ArgumentError('Invalid URL scheme. Remote attachments require http or https URLs. '
          'Received: ${url.split('://').first}://');
    }

    return RemoteAttachmentContent(
      url: url,
      contentDigest: contentDigest,
      secret: secret,
      salt: salt,
      nonce: nonce,
      scheme: Uri.parse(url).scheme,
      contentLength: contentLength,
      filename: filename,
      description: description,
    );
  }

  // Add serialization methods
  Map<String, dynamic> toJson() => {
        'url': url,
        'contentDigest': contentDigest,
        'secret': bytesToHex(secret, include0x: false),
        'salt': bytesToHex(salt, include0x: false),
        'nonce': bytesToHex(nonce, include0x: false),
        'scheme': scheme,
        'contentLength': contentLength,
        'filename': filename,
        if (description != null) 'description': description,
      };

  factory RemoteAttachmentContent.fromJson(Map<String, dynamic> json) {
    return RemoteAttachmentContent(
      url: json['url'] as String,
      contentDigest: json['contentDigest'] as String,
      secret: hexToBytes(json['secret']),
      salt: hexToBytes(json['salt']),
      nonce: hexToBytes(json['nonce']),
      scheme: json['scheme'] as String,
      contentLength: json['contentLength'] as int,
      filename: json['filename'] as String,
      description: json['description'] as String?,
    );
  }

  @override
  String toString() {
    return 'RemoteAttachmentContent{url: $url, filename: $filename}';
  }
}

/// Reply content data class
class Reply {
  final String reference;
  final dynamic content;
  final ContentType contentType;

  Reply({
    required this.reference,
    required this.content,
    required this.contentType,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      reference: json['reference'] as String,
      content: json['content'],
      contentType: ContentType.fromMap(json['contentType']),
    );
  }

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'content': content,
        'contentType': contentType.toMap(),
      };
}

/// Reply codec implementation
class ReplyCodec extends XMTPCodec {
  final XMTPCodecRegistry codecRegistry;

  ReplyCodec(this.codecRegistry);

  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'reply';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! Reply) {
      throw const FormatException('Content must be Reply');
    }

    // Get the codec for the nested content
    final codec = codecRegistry.getCodec(
      content.contentType.authorityId,
      content.contentType.typeId,
    );

    if (codec == null) {
      throw Exception('No codec found for content type: ${content.contentType.authorityId}/${content.contentType.typeId}');
    }

    // Encode the nested content
    final encodedContent = await codec.encode(content.content);

    // Build the nested EncodedContent protobuf
    final nestedEncodedContent = EncodedContent()
      ..type = (ContentTypeId()
        ..authorityId = content.contentType.authorityId
        ..typeId = content.contentType.typeId
        ..versionMajor = content.contentType.versionMajor
        ..versionMinor = 0)
      ..content = encodedContent['content'] as Uint8List;

    // Add parameters from the nested codec
    final nestedParameters = encodedContent['parameters'] as Map<String, dynamic>?;
    if (nestedParameters != null) {
      nestedParameters.forEach((key, value) {
        nestedEncodedContent.parameters[key] = value.toString();
      });
    }

    // Serialize the nested EncodedContent to bytes
    final nestedBytes = nestedEncodedContent.writeToBuffer();

    return {
      'content': Uint8List.fromList(nestedBytes),
      'parameters': {
        'reference': content.reference,
        // Store contentType for backward compatibility <- this is the reply type (Text, attachmente,etc.)
        'contentType': '${content.contentType.authorityId}/${content.contentType.typeId}',
      },
      'type': {
        'authorityId': authorityId,
        'typeId': typeId,
        'versionMajor': versionMajor,
        'versionMinor': versionMinor,
      }
    };
  }

  @override
  Future<Reply> decode(EncodedContent encodedContent) async {
    final reference = encodedContent.parameters['reference'];
    if (reference == null) {
      throw Exception('Reply: Invalid Content: missing reference');
    }

    // Parse the nested EncodedContent from bytes
    // The bytes contain a complete EncodedContent protobuf, not just raw content
    final replyEncodedContent = EncodedContent.fromBuffer(encodedContent.content);

    // Get the codec for the nested content type
    final replyCodec = codecRegistry.getCodec(
      replyEncodedContent.type.authorityId,
      replyEncodedContent.type.typeId,
    );

    if (replyCodec == null) {
      throw Exception('Reply: No codec found for content type: ${replyEncodedContent.type.authorityId}/${replyEncodedContent.type.typeId}');
    }

    // Decode the nested content using its codec (recursive)
    final replyContent = await replyCodec.decode(replyEncodedContent);

    return Reply(
      reference: reference,
      content: replyContent,
      contentType: ContentType(
        authorityId: replyEncodedContent.type.authorityId,
        typeId: replyEncodedContent.type.typeId,
        versionMajor: replyEncodedContent.type.versionMajor,
      ),
    );
  }

  @override
  String? getFallback(dynamic content) {
    if (content is Reply) {
      return 'Replied with "${content.content}" to an earlier message';
    }
    return null;
  }
}

/// Reaction action enum
enum ReactionAction {
  added,
  removed,
}

/// Reaction content data class
class Reaction {
  final String reference;
  final String content;
  final ReactionAction action;
  final String schema;

  Reaction({
    required this.reference,
    required this.content,
    required this.action,
    this.schema = 'unicode',
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      reference: json['reference'] as String,
      content: json['content'] as String,
      action: ReactionAction.values.firstWhere(
        (e) => e.toString().split('.').last == json['action'],
        orElse: () => ReactionAction.added,
      ),
      schema: json['schema'] as String? ?? 'unicode',
    );
  }

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'content': content,
        'action': action.toString().split('.').last,
        'schema': schema,
      };
}

/// Reaction codec v2 implementation
class ReactionV2Codec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'reaction';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! Reaction) {
      throw const FormatException('Content must be Reaction');
    }

    final reactionData = {
      'reference': content.reference,
      'action': content.action.toString().split('.').last,
      'content': content.content,
      'schema': content.schema,
    };

    return {
      'content': Uint8List.fromList(utf8.encode(jsonEncode(reactionData))),
      'parameters': <String, dynamic>{},
    };
  }

  @override
  Future<Reaction> decode(EncodedContent encodedContent) async {
    try {
      final jsonString = utf8.decode(encodedContent.content);
      final Map<String, dynamic> reactionData = jsonDecode(jsonString);
      return Reaction.fromJson(reactionData);
    } catch (e) {
      throw FormatException('Failed to decode reaction: $e');
    }
  }

  @override
  String? getFallback(dynamic content) {
    if (content is Reaction) {
      switch (content.action) {
        case ReactionAction.added:
          return 'Reacted "${content.content}" to an earlier message';
        case ReactionAction.removed:
          return 'Removed "${content.content}" from an earlier message';
      }
    }
    return null;
  }

  @override
  bool shouldPush(dynamic content) {
    if (content is Reaction) {
      return content.action == ReactionAction.added;
    }
    return false;
  }
}

/// Group updated codec implementation
/// Uses protobuf-generated GroupUpdated class from transcript_messages.pb.dart
class GroupUpdatedCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'group_updated';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! GroupUpdated) {
      throw const FormatException('Content must be GroupUpdated');
    }

    // Serialize protobuf to bytes
    return {
      'content': Uint8List.fromList(content.writeToBuffer()),
      'parameters': <String, dynamic>{},
    };
  }

  @override
  Future<GroupUpdated> decode(EncodedContent encodedContent) async {
    try {
      // Deserialize protobuf from bytes
      return GroupUpdated.fromBuffer(encodedContent.content);
    } catch (e) {
      print('GroupUpdatedCodec: Failed to decode protobuf: $e');
      // Return empty GroupUpdated on error
      return GroupUpdated();
    }
  }

  @override
  String? getFallback(dynamic content) {
    // Return null to indicate no fallback text (group updates are metadata)
    return null;
  }

  @override
  bool shouldPush(dynamic content) {
    // Group update messages should not trigger push notifications
    return false;
  }
}

class RemoteAttachmentCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'remoteStaticAttachment';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  static Future<Uint8List> _decrypt({
    required Uint8List secret,
    required Uint8List salt,
    required Uint8List nonce,
    required Uint8List payload,
  }) async {
    final hkdf = HKDFKeyDerivator(SHA256Digest());
    final params = HkdfParameters(secret, 32, salt);
    hkdf.init(params);
    final key = hkdf.process(Uint8List(0));

    final cipher = GCMBlockCipher(AESFastEngine());
    final params2 = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0));
    cipher.init(false, params2);

    final decrypted = Uint8List(cipher.getOutputSize(payload.length));
    var offset = 0;
    offset += cipher.processBytes(payload, 0, payload.length, decrypted, offset);
    final finalLen = cipher.doFinal(decrypted, offset);

    // Return only the actual decrypted data (without padding)
    // doFinal returns the number of bytes written to the output buffer
    final totalLen = offset + finalLen;
    return Uint8List.sublistView(decrypted, 0, totalLen);
  }

  /// AES-256-GCM with HKDF-SHA256-derived key. Inverse of [_decrypt].
  /// Matches the XMTP remote-attachment encryption scheme used by every
  /// reference SDK (xmtp-android Crypto.encrypt, xmtp-ios Crypto.encrypt,
  /// xmtp-js encrypt/encryption.ts).
  static Future<Uint8List> _encrypt({
    required Uint8List secret,
    required Uint8List salt,
    required Uint8List nonce,
    required Uint8List plaintext,
  }) async {
    final hkdf = HKDFKeyDerivator(SHA256Digest());
    hkdf.init(HkdfParameters(secret, 32, salt));
    final key = hkdf.process(Uint8List(0));

    final cipher = GCMBlockCipher(AESFastEngine());
    cipher.init(
      true,
      AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
    );

    final out = Uint8List(cipher.getOutputSize(plaintext.length));
    var offset = 0;
    offset += cipher.processBytes(plaintext, 0, plaintext.length, out, offset);
    final finalLen = cipher.doFinal(out, offset);
    return Uint8List.sublistView(out, 0, offset + finalLen);
  }

  /// Spec-compliant counterpart to [load] / [_fetchDecryptAndParse].
  ///
  /// Wraps [content] in an [EncodedContent] envelope using [codec], serializes
  /// the envelope to protobuf bytes, then AES-256-GCM encrypts those bytes with
  /// a fresh random secret/salt/nonce. The output is the exact wire shape
  /// produced by xmtp-android `RemoteAttachmentCodec.encodeEncrypted<T>`,
  /// xmtp-ios `RemoteAttachment.encodeEncrypted`, and xmtp-js
  /// `RemoteAttachmentCodec.encodeEncrypted<T>` — interoperable with every
  /// spec-compliant XMTP client.
  ///
  /// Pre-1.0.5 we encrypted the raw inner payload directly; that decrypted
  /// into bare bytes, not into a protobuf, and native SDKs threw on parse
  /// (their `EncodedContent.parseFrom` / `EncodedContent(serializedData:)` /
  /// `proto.EncodedContent.decode` paths have no fallback). Callers should
  /// always use this helper — `_encrypt` is private on purpose.
  ///
  /// [filename] populates the optional `RemoteAttachmentContent.filename`
  /// envelope parameter that travels alongside the URL — purely informational
  /// for receivers that want to display a name before downloading the payload.
  /// The authoritative filename lives inside the encrypted envelope.
  static Future<EncryptedEncodedContent> encodeEncrypted<T>(
    T content,
    XMTPCodec codec, {
    String? filename,
  }) async {
    final encoded = await codec.encode(content);
    final innerContent = encoded['content'];
    final Uint8List innerBytes;
    if (innerContent is Uint8List) {
      innerBytes = innerContent;
    } else if (innerContent is List<int>) {
      innerBytes = Uint8List.fromList(innerContent);
    } else {
      throw FormatException(
        'codec.encode returned non-bytes "content": ${innerContent.runtimeType}',
      );
    }

    final envelope = EncodedContent()
      ..type = (ContentTypeId()
        ..authorityId = codec.authorityId
        ..typeId = codec.typeId
        ..versionMajor = codec.versionMajor
        ..versionMinor = codec.versionMinor)
      ..content = innerBytes;
    final innerParams = encoded['parameters'];
    if (innerParams is Map) {
      innerParams.forEach((k, v) {
        envelope.parameters[k.toString()] = v.toString();
      });
    }

    final serialized = Uint8List.fromList(envelope.writeToBuffer());

    final random = Random.secure();
    final secret = Uint8List(32);
    final salt = Uint8List(32);
    final nonce = Uint8List(12);
    for (var i = 0; i < 32; i++) {
      secret[i] = random.nextInt(256);
      salt[i] = random.nextInt(256);
    }
    for (var i = 0; i < 12; i++) {
      nonce[i] = random.nextInt(256);
    }

    final ciphertext = await _encrypt(
      secret: secret,
      salt: salt,
      nonce: nonce,
      plaintext: serialized,
    );

    final digestBytes = SHA256Digest().process(ciphertext);
    final contentDigest =
        digestBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return EncryptedEncodedContent(
      contentDigest: contentDigest,
      secret: secret,
      salt: salt,
      nonce: nonce,
      payload: ciphertext,
      contentLength: ciphertext.length,
      filename: filename,
    );
  }

  static Future<Uint8List> _fetchAndDecrypt(RemoteAttachmentContent content, {int maxRetries = 3}) async {
    int retryCount = 0;
    Duration retryDelay = const Duration(seconds: 1);

    while (true) {
      try {
        // Fetch with timeout
        final response = await http
            .get(
          Uri.parse(content.url),
        )
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timed out after 30 seconds fetching ${content.url}');
          },
        );

        // Handle rate limiting with retry
        if (response.statusCode == 429) {
          if (retryCount >= maxRetries) {
            throw Exception('HTTP 429: Too Many Requests - Rate limit exceeded after $maxRetries retries for ${content.url}');
          }

          retryCount++;
          print('RemoteAttachment: Rate limited (429), retrying in ${retryDelay.inSeconds}s (attempt $retryCount/$maxRetries)');
          await Future.delayed(retryDelay);
          retryDelay *= 2; // Exponential backoff
          continue;
        }

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}: Failed to fetch remote attachment from ${content.url}');
        }

        final payload = response.bodyBytes;

        if (payload.isEmpty) {
          throw Exception('Received empty payload from ${content.url}');
        }

        // Verify SHA-256 digest
        final digest = sha256.convert(payload).toString();
        if (digest != content.contentDigest) {
          throw Exception('Content digest mismatch for ${content.filename}. '
              'Expected: ${content.contentDigest}, Got: $digest');
        }

        // Decrypt the payload
        return _decrypt(
          secret: content.secret,
          salt: content.salt,
          nonce: content.nonce,
          payload: payload,
        );
      } on Exception catch (e) {
        // If it's not a rate limit error, rethrow immediately
        if (!e.toString().contains('429')) {
          rethrow;
        }
        // Rate limit error will be handled by the continue above
      }
    }
  }

  /// Fetches, decrypts, and parses a remote attachment into AttachmentContent
  static Future<AttachmentContent> _fetchDecryptAndParse(RemoteAttachmentContent content) async {
    print('RemoteAttachment: Fetching and decrypting ${content.filename} from ${content.url}');

    // Step 1-3: Fetch, verify digest, and decrypt
    final decryptedBytes = await _fetchAndDecrypt(content);

    print('RemoteAttachment: Decrypted ${decryptedBytes.length} bytes');
    print('RemoteAttachment: First 20 bytes: ${decryptedBytes.take(20).toList()}');

    try {
      // Step 4: Parse decrypted bytes as EncodedContent protobuf
      // The decrypted data is an EncodedContent that contains the actual attachment
      final encodedContent = EncodedContent.fromBuffer(decryptedBytes);

      print('RemoteAttachment: Protobuf parsed successfully');
      print('RemoteAttachment: Content type: ${encodedContent.type.authorityId}/${encodedContent.type.typeId}');
      print('RemoteAttachment: Content size: ${encodedContent.content.length} bytes');
      print('RemoteAttachment: Parameters: ${encodedContent.parameters}');

      // Step 5: Extract attachment data from EncodedContent
      // The EncodedContent should be of type 'attachment' containing the actual file data
      final attachmentCodec = AttachmentCodec();
      final attachment = await attachmentCodec.decode(encodedContent);

      print('RemoteAttachment: Successfully loaded ${attachment.filename} (${attachment.data.length} bytes, ${attachment.mimeType})');

      return attachment;
    } catch (e) {
      print('RemoteAttachment: Failed to parse as protobuf: $e');
      print('RemoteAttachment: Attempting to use decrypted bytes directly as attachment data');

      // Fallback: Maybe the decrypted bytes ARE the attachment data directly?
      // Try to infer MIME type from filename. Covers the formats our clients
      // actually send (image + video + pdf); anything else stays
      // application/octet-stream and the receiver renders the generic-file
      // bubble.
      String mimeType = 'application/octet-stream';
      final lowerName = content.filename.toLowerCase();
      if (lowerName.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (lowerName.endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (lowerName.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else if (lowerName.endsWith('.heic') || lowerName.endsWith('.heif')) {
        mimeType = 'image/heic';
      } else if (lowerName.endsWith('.mp4')) {
        mimeType = 'video/mp4';
      } else if (lowerName.endsWith('.mov')) {
        mimeType = 'video/quicktime';
      } else if (lowerName.endsWith('.webm')) {
        mimeType = 'video/webm';
      } else if (lowerName.endsWith('.m4v')) {
        mimeType = 'video/x-m4v';
      } else if (lowerName.endsWith('.pdf')) {
        mimeType = 'application/pdf';
      }

      return AttachmentContent(
        data: decryptedBytes,
        filename: content.filename,
        mimeType: mimeType,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! RemoteAttachmentContent) {
      throw const FormatException('Content must be RemoteAttachmentContent');
    }
    if (!content.url.startsWith('http')) {
      throw Exception('Scheme must be http or https');
    }
    final scheme = Uri.parse(content.url).scheme; // 'http' or 'https'
    final parameters = {
      'contentDigest': content.contentDigest,
      'salt': bytesToHex(content.salt, include0x: false),
      'nonce': bytesToHex(content.nonce, include0x: false),
      'secret': bytesToHex(content.secret, include0x: false),
      'scheme': scheme,
      'contentLength': content.contentLength.toString(),
      'filename': content.filename,
    };
    if (content.description != null && content.description!.isNotEmpty) {
      parameters['description'] = content.description!;
    }
    return {
      'content': utf8.encode(content.url),
      'parameters': parameters,
    };
  }

  @override
  Future<RemoteAttachmentContent> decode(EncodedContent encodedContent) async {
    final url = utf8.decode(encodedContent.content);
    final contentDigest = encodedContent.parameters['contentDigest'];
    final secretHex = encodedContent.parameters['secret'];
    final saltHex = encodedContent.parameters['salt'];
    final nonceHex = encodedContent.parameters['nonce'];
    final scheme = encodedContent.parameters['scheme'];
    final contentLengthStr = encodedContent.parameters['contentLength'];
    final filename = encodedContent.parameters['filename'];

    if (contentDigest == null || secretHex == null || saltHex == null || nonceHex == null || scheme == null || contentLengthStr == null || filename == null) {
      throw Exception('Missing required parameters for remote attachment');
    }

    // Accept http and https — LAN servers use http, production uses https
    final normalizedScheme = scheme.replaceAll('://', '');
    if (normalizedScheme != 'https' && normalizedScheme != 'http') {
      throw Exception('Invalid scheme for remote attachment: "$scheme". '
          'Must be http or https.');
    }

    final description = encodedContent.parameters['description'];

    return RemoteAttachmentContent(
      url: url,
      contentDigest: contentDigest,
      secret: hexToBytes(secretHex),
      salt: hexToBytes(saltHex),
      nonce: hexToBytes(nonceHex),
      scheme: normalizedScheme,
      contentLength: int.parse(contentLengthStr),
      filename: filename,
      description: description,
    );
  }

  @override
  String? getFallback(dynamic content) {
    if (content is RemoteAttachmentContent) {
      return 'Can\'t display "${content.filename}". This app doesn\'t support remote attachments.';
    }
    return null;
  }

  /// Loads a remote attachment by fetching, decrypting, and parsing it
  ///
  /// This method handles the complete flow of:
  /// 1. Fetching the encrypted payload from the remote URL
  /// 2. Verifying the content digest (SHA-256)
  /// 3. Decrypting the payload using AES-GCM
  /// 4. Parsing the decrypted bytes as an AttachmentContent
  ///
  /// Note: This method does NOT handle caching. The caller is responsible for
  /// checking cache before calling this method and storing the result afterward.
  static Future<AttachmentContent> load(RemoteAttachmentContent content) async {
    try {
      print('RemoteAttachment: Fetching from network');
      final attachment = await _fetchDecryptAndParse(content);
      return attachment;
    } catch (e) {
      print('Error loading remote attachment: $e');
      rethrow; // Rethrow to preserve stack trace
    }
  }
}

/// Read receipt marker - empty payload, timestamp comes from message.sent
class ReadReceipt {
  const ReadReceipt();
}

/// Read receipt codec implementation
/// Content type: xmtp.org/readReceipt v1.0
class ReadReceiptCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'readReceipt';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    return {
      'content': Uint8List(0), // Empty payload per XMTP spec
      'parameters': <String, dynamic>{},
    };
  }

  @override
  Future<ReadReceipt> decode(EncodedContent encodedContent) async {
    return const ReadReceipt();
  }

  @override
  String? getFallback(dynamic content) => null;

  @override
  bool shouldPush(dynamic content) => false;
}

// ============================================================================
// Transaction Reference — JSON wire format (xmtp.org/transactionReference/1.0)
// ----------------------------------------------------------------------------
// XIP-21. Canonical reference: libxmtp
//   crates/xmtp_content_types/src/transaction_reference.rs
// Canonical wire shape is a FLAT JSON object (NOT wrapped):
//   { namespace?, networkId, reference, metadata? }
// where metadata = { transactionType, currency, amount, decimals,
//                    fromAddress, toAddress }.
//
// ENCODE is canonical-compliant (flat, only set fields emitted), so what we
// send interoperates with libxmtp / xmtp-js / Base.
// DECODE is deliberately lenient (Postel's law): real-world senders (e.g. Base
// payment agents) have been observed emitting the payload WRAPPED under a
// "transactionReference" key and with PARTIAL metadata. We unwrap, treat every
// metadata field as optional, accept networkId as string-or-number, and keep
// any unknown keys in `extra` so nothing is silently dropped.
// ============================================================================

/// Optional metadata for a transaction reference.
///
/// Canonical libxmtp lists all six fields, but we keep them optional on decode
/// for non-conformant senders. `extra` preserves any keys outside the canonical
/// schema so they can still be displayed.
class TransactionMetadata {
  final String? transactionType;
  final String? currency;
  final double? amount;
  final int? decimals;
  final String? fromAddress;
  final String? toAddress;
  final Map<String, dynamic> extra;

  TransactionMetadata({
    this.transactionType,
    this.currency,
    this.amount,
    this.decimals,
    this.fromAddress,
    this.toAddress,
    this.extra = const {},
  });

  static const _known = {
    'transactionType', 'currency', 'amount', 'decimals', 'fromAddress',
    'toAddress',
  };

  factory TransactionMetadata.fromJson(Map<String, dynamic> json) {
    return TransactionMetadata(
      transactionType: json['transactionType'] as String?,
      currency: json['currency'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      decimals: (json['decimals'] as num?)?.toInt(),
      fromAddress: json['fromAddress'] as String?,
      toAddress: json['toAddress'] as String?,
      extra: {
        for (final e in json.entries)
          if (!_known.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        if (transactionType != null) 'transactionType': transactionType,
        if (currency != null) 'currency': currency,
        if (amount != null) 'amount': amount,
        if (decimals != null) 'decimals': decimals,
        if (fromAddress != null) 'fromAddress': fromAddress,
        if (toAddress != null) 'toAddress': toAddress,
        ...extra,
      };

  @override
  String toString() => 'TransactionMetadata(${toJson()})';
}

/// A reference to an on-chain transaction (a receipt).
class TransactionReference {
  final String? namespace;

  /// Chain id, normalized to a string (the wire allows string or number).
  final String networkId;

  /// The on-chain transaction hash.
  final String reference;
  final TransactionMetadata? metadata;

  TransactionReference({
    this.namespace,
    required this.networkId,
    required this.reference,
    this.metadata,
  });

  factory TransactionReference.fromJson(Map<String, dynamic> json) {
    // Tolerate a wrapped envelope: some senders (e.g. Base payment agents) emit
    // {"transactionReference": {...}} instead of the canonical flat object.
    // Keeping this here means both the codec and any reload-from-storage path
    // share one wire-tolerant entry point.
    final inner = json['transactionReference'];
    final obj = inner is Map ? Map<String, dynamic>.from(inner) : json;

    final rawNetworkId = obj['networkId'];
    final networkId = rawNetworkId == null
        ? ''
        : (rawNetworkId is String ? rawNetworkId : rawNetworkId.toString());

    final rawMeta = obj['metadata'];
    final metadata = rawMeta is Map
        ? TransactionMetadata.fromJson(Map<String, dynamic>.from(rawMeta))
        : null;

    return TransactionReference(
      namespace: obj['namespace'] as String?,
      networkId: networkId,
      reference: (obj['reference'] as String?) ?? '',
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        if (namespace != null) 'namespace': namespace,
        'networkId': networkId,
        'reference': reference,
        if (metadata != null) 'metadata': metadata!.toJson(),
      };

  @override
  String toString() =>
      'TransactionReference(networkId: $networkId, reference: $reference, '
      'namespace: $namespace, metadata: $metadata)';
}

/// Transaction reference codec — JSON wire format (XIP-21).
class TransactionReferenceCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'transactionReference';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! TransactionReference) {
      throw const FormatException('Content must be TransactionReference');
    }
    // Canonical flat JSON — interoperable with libxmtp / xmtp-js / Base.
    final jsonBytes = utf8.encode(jsonEncode(content.toJson()));
    return {
      'content': Uint8List.fromList(jsonBytes),
      'parameters': <String, dynamic>{},
    };
  }

  @override
  Future<TransactionReference> decode(EncodedContent encodedContent) async {
    final jsonString = utf8.decode(encodedContent.content);
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw FormatException(
          'TransactionReference: expected a JSON object, got ${decoded.runtimeType}');
    }
    // fromJson tolerates both the canonical flat object and a wrapped envelope.
    return TransactionReference.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  String? getFallback(dynamic content) {
    if (content is TransactionReference) {
      if (content.reference.isNotEmpty) {
        return '[Crypto transaction] Use a blockchain explorer to learn more '
            'using the transaction hash: ${content.reference}';
      }
      return 'Crypto transaction';
    }
    return null;
  }

  @override
  bool shouldPush(dynamic content) => true;
}

// ============================================================================
// Wallet Send Calls — JSON wire format (xmtp.org/walletSendCalls/1.0)
// ----------------------------------------------------------------------------
// XIP-59 / EIP-5792 `wallet_sendCalls`. Canonical reference: libxmtp
//   crates/xmtp_content_types/src/wallet_send_calls.rs
// Canonical wire shape is a FLAT JSON object:
//   { version, chainId, from, calls:[ {to?, data?, value?, gas?, metadata?} ],
//     capabilities? }
// where call metadata = { description, transactionType, ...extra } (the extra
// keys are flattened as siblings via serde `#[serde(flatten)]`).
//
// This is the actionable "invoice": the recipient reviews the calls, signs, and
// broadcasts, then replies with a TransactionReference receipt. ENCODE is
// canonical-flat; DECODE is lenient (optional fields, flattened extras).
// ============================================================================

/// Per-call metadata for a wallet send calls request.
class WalletCallMetadata {
  final String? description;
  final String? transactionType;

  /// Extra keys flattened alongside description/transactionType on the wire.
  final Map<String, dynamic> extra;

  WalletCallMetadata({
    this.description,
    this.transactionType,
    this.extra = const {},
  });

  static const _known = {'description', 'transactionType'};

  factory WalletCallMetadata.fromJson(Map<String, dynamic> json) {
    return WalletCallMetadata(
      description: json['description'] as String?,
      transactionType: json['transactionType'] as String?,
      extra: {
        for (final e in json.entries)
          if (!_known.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        if (description != null) 'description': description,
        if (transactionType != null) 'transactionType': transactionType,
        ...extra,
      };

  @override
  String toString() => 'WalletCallMetadata(${toJson()})';
}

/// A single call within a wallet send calls request (EIP-5792 shape).
class WalletCall {
  /// Target address (hex).
  final String? to;

  /// Calldata (hex).
  final String? data;

  /// Value in wei (hex).
  final String? value;

  /// Gas limit (hex).
  final String? gas;
  final WalletCallMetadata? metadata;

  WalletCall({this.to, this.data, this.value, this.gas, this.metadata});

  factory WalletCall.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['metadata'];
    return WalletCall(
      to: json['to'] as String?,
      data: json['data'] as String?,
      value: json['value'] as String?,
      gas: json['gas'] as String?,
      metadata: rawMeta is Map
          ? WalletCallMetadata.fromJson(Map<String, dynamic>.from(rawMeta))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (to != null) 'to': to,
        if (data != null) 'data': data,
        if (value != null) 'value': value,
        if (gas != null) 'gas': gas,
        if (metadata != null) 'metadata': metadata!.toJson(),
      };

  @override
  String toString() => 'WalletCall(${toJson()})';
}

/// A wallet send calls request (an invoice / transaction request).
class WalletSendCalls {
  final String version;

  /// Chain id in hex (e.g. "0x2105" for Base).
  final String chainId;

  /// The address expected to send the calls (hex).
  final String from;
  final List<WalletCall> calls;
  final Map<String, dynamic>? capabilities;

  WalletSendCalls({
    required this.version,
    required this.chainId,
    required this.from,
    required this.calls,
    this.capabilities,
  });

  factory WalletSendCalls.fromJson(Map<String, dynamic> json) {
    final rawCalls = json['calls'];
    final calls = <WalletCall>[];
    if (rawCalls is List) {
      for (final c in rawCalls) {
        if (c is Map) {
          calls.add(WalletCall.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }
    final rawCaps = json['capabilities'];
    return WalletSendCalls(
      version: (json['version'] as String?) ?? '',
      chainId: (json['chainId'] as String?) ?? '',
      from: (json['from'] as String?) ?? '',
      calls: calls,
      capabilities:
          rawCaps is Map ? Map<String, dynamic>.from(rawCaps) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'chainId': chainId,
        'from': from,
        'calls': calls.map((c) => c.toJson()).toList(),
        if (capabilities != null) 'capabilities': capabilities,
      };

  @override
  String toString() =>
      'WalletSendCalls(chainId: $chainId, from: $from, calls: $calls, '
      'capabilities: $capabilities)';
}

/// Wallet send calls codec — JSON wire format (XIP-59 / EIP-5792).
class WalletSendCallsCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'walletSendCalls';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! WalletSendCalls) {
      throw const FormatException('Content must be WalletSendCalls');
    }
    final jsonBytes = utf8.encode(jsonEncode(content.toJson()));
    return {
      'content': Uint8List.fromList(jsonBytes),
      'parameters': <String, dynamic>{},
    };
  }

  @override
  Future<WalletSendCalls> decode(EncodedContent encodedContent) async {
    final jsonString = utf8.decode(encodedContent.content);
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw FormatException(
          'WalletSendCalls: expected a JSON object, got ${decoded.runtimeType}');
    }
    return WalletSendCalls.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  String? getFallback(dynamic content) {
    if (content is WalletSendCalls) {
      return '[Transaction request generated]: ${jsonEncode(content.toJson())}';
    }
    return null;
  }

  @override
  bool shouldPush(dynamic content) => true;
}

// ============================================================================
// Delete Message — Protobuf wire format (xmtp.org/deleteMessage/1.0)
// ============================================================================

/// Delete message codec — wraps the protobuf-generated DeleteMessage
class DeleteMessageCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'deleteMessage';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! proto_delete.DeleteMessage) {
      throw const FormatException('Content must be DeleteMessage');
    }
    return {
      'content': Uint8List.fromList(content.writeToBuffer()),
      'parameters': <String, dynamic>{},
    };
  }

  @override
  Future<proto_delete.DeleteMessage> decode(EncodedContent encodedContent) async {
    try {
      return proto_delete.DeleteMessage.fromBuffer(encodedContent.content);
    } catch (e) {
      throw FormatException('Failed to decode DeleteMessage: $e');
    }
  }

  @override
  String? getFallback(dynamic content) => null;

  @override
  bool shouldPush(dynamic content) => false;
}

// ============================================================================
// Leave Request — Protobuf wire format (xmtp.org/leaveRequest/1.0)
// ============================================================================

/// Leave request codec — wraps the protobuf-generated LeaveRequest
class LeaveRequestCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'leaveRequest';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! proto_leave.LeaveRequest) {
      throw const FormatException('Content must be LeaveRequest');
    }
    return {
      'content': Uint8List.fromList(content.writeToBuffer()),
      'parameters': <String, dynamic>{},
    };
  }

  @override
  Future<proto_leave.LeaveRequest> decode(EncodedContent encodedContent) async {
    try {
      return proto_leave.LeaveRequest.fromBuffer(encodedContent.content);
    } catch (e) {
      throw FormatException('Failed to decode LeaveRequest: $e');
    }
  }

  @override
  String? getFallback(dynamic content) =>
      'A member has requested leaving the group';

  @override
  bool shouldPush(dynamic content) => false;
}

// ============================================================================
// Multi Remote Attachment — Protobuf wire format
// (xmtp.org/multiRemoteStaticContent/1.0)
// ============================================================================

/// Multi remote attachment codec — wraps the protobuf-generated MultiRemoteAttachment
class MultiRemoteAttachmentCodec extends XMTPCodec {
  @override
  String get authorityId => 'xmtp.org';

  @override
  String get typeId => 'multiRemoteStaticContent';

  @override
  int get versionMajor => 1;

  @override
  int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    if (content is! proto_multi.MultiRemoteAttachment) {
      throw const FormatException('Content must be MultiRemoteAttachment');
    }
    return {
      'content': Uint8List.fromList(content.writeToBuffer()),
      'parameters': <String, dynamic>{},
    };
  }

  @override
  Future<proto_multi.MultiRemoteAttachment> decode(EncodedContent encodedContent) async {
    try {
      return proto_multi.MultiRemoteAttachment.fromBuffer(encodedContent.content);
    } catch (e) {
      throw FormatException('Failed to decode MultiRemoteAttachment: $e');
    }
  }

  @override
  String? getFallback(dynamic content) {
    if (content is proto_multi.MultiRemoteAttachment) {
      final count = content.attachments.length;
      return '[$count attachment${count != 1 ? 's' : ''}]';
    }
    return null;
  }

  @override
  bool shouldPush(dynamic content) => true;
}
