import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:xmtp_plugin/generated/content.pb.dart' as proto;
import 'xmtp_plugin_platform_interface.dart';
import 'src/rust/api/client.dart' as rust_client;
import 'src/rust/api/messaging.dart' as rust_messaging;
import 'src/rust/api/conversations.dart' as rust_conversations;
import 'src/rust/api/groups.dart' as rust_groups;
import 'src/rust/api/consent.dart' as rust_consent;
import 'src/rust/api/inbox.dart' as rust_inbox;
import 'src/rust/api/signing.dart' as rust_signing;
import 'src/rust/frb_generated.dart';

/// Windows implementation of the XMTP Flutter plugin.
///
/// This implementation uses dart:ffi via flutter_rust_bridge to call
/// Rust code directly, bypassing the C++ method channel entirely.
class XmtpPluginWindows extends XmtpPluginPlatform {
  static bool _initialized = false;

  /// Registers this class as the platform implementation.
  static void registerWith() {
    XmtpPluginPlatform.instance = XmtpPluginWindows();
  }

  /// Ensure the Rust library is initialized.
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await RustLib.init();
      _initialized = true;
    }
  }

  /// Sync guard for non-async methods (e.g., streaming).
  /// Assumes initializeClient() was already called.
  void _ensureInitializedSync() {
    if (!_initialized) {
      throw StateError(
          'RustLib not initialized. Call initializeClient() first.');
    }
  }

  // ============================================================================
  // PLATFORM VERSION
  // ============================================================================

  @override
  Future<String?> getPlatformVersion() async {
    await _ensureInitialized();
    return rust_client.getPlatformVersion();
  }

  // ============================================================================
  // CLIENT INITIALIZATION (Phase 1)
  // ============================================================================

  @override
  Future<Uint8List> generatePrivateKey() async {
    await _ensureInitialized();
    return rust_client.generatePrivateKey();
  }

  @override
  Future<String?> initializeClient(Uint8List privateKey, Uint8List dbKey, {String environment = 'production'}) async {
    await _ensureInitialized();
    return rust_client.initializeClient(
      privateKey: privateKey.toList(),
      dbEncryptionKey: dbKey.toList(),
      environment: environment,
    );
  }

  @override
  Future<String?> getClientAddress() async {
    await _ensureInitialized();
    return rust_client.getClientAddress();
  }

  @override
  Future<String?> getClientInboxId() async {
    await _ensureInitialized();
    return rust_client.getClientInboxId();
  }

  // ============================================================================
  // MESSAGING (Phase 2)
  // ============================================================================

  @override
  Future<String?> sendMessage(String recipientAddress, dynamic message,
      String authorityId, String typeId, int versionMajor) async {
    await _ensureInitialized();
    // Extract content bytes from the encoded message map
    final contentBytes = _extractContentBytes(message, authorityId, typeId,
        versionMajor);
    return rust_messaging.sendMessage(
        address: recipientAddress, contentBytes: contentBytes);
  }

  @override
  Future<String?> sendMessageByInboxId(String recipientInboxId,
      dynamic message, String authorityId, String typeId,
      int versionMajor) async {
    await _ensureInitialized();
    final contentBytes = _extractContentBytes(message, authorityId, typeId,
        versionMajor);
    return rust_messaging.sendMessageByInboxId(
        inboxId: recipientInboxId, contentBytes: contentBytes);
  }

  @override
  Future<String?> sendGroupMessage(String topic, dynamic message,
      String authorityId, String typeId, int versionMajor) async {
    await _ensureInitialized();
    final contentBytes = _extractContentBytes(message, authorityId, typeId,
        versionMajor);
    return rust_messaging.sendGroupMessage(
        topic: topic, contentBytes: contentBytes);
  }

  @override
  Stream<Map<String, dynamic>> subscribeToAllMessages() {
    _ensureInitializedSync();
    return rust_messaging.subscribeToAllMessages().map(_messageInfoToMap);
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesAfterDate(
      String peerAddress, DateTime fromDate) async {
    await _ensureInitialized();
    final messages = await rust_messaging.getMessagesAfterDate(
        peerAddress: peerAddress,
        fromDateMs: fromDate.millisecondsSinceEpoch);
    return messages.map(_messageInfoToMap).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesAfterDateByTopic(
      String topic, DateTime fromDate) async {
    await _ensureInitialized();
    final messages = await rust_messaging.getMessagesAfterDateByTopic(
        topic: topic,
        fromDateMs: fromDate.millisecondsSinceEpoch);
    return messages.map(_messageInfoToMap).toList();
  }

  @override
  Future<Map<String, dynamic>> loadRemoteAttachment(
      Map<String, dynamic> params) async {
    await _ensureInitialized();
    final attachment = await rust_messaging.loadRemoteAttachment(
      url: params['url'] as String,
      contentDigest: params['contentDigest'] as String,
      secret: List<int>.from(params['secret']),
      salt: List<int>.from(params['salt']),
      nonce: List<int>.from(params['nonce']),
      scheme: params['scheme'] as String,
      contentLength: params['contentLength'] as int?,
      filename: params['filename'] as String?,
    );
    return {
      'filename': attachment.filename,
      'mimeType': attachment.mimeType,
      'data': attachment.data,
    };
  }

  // ============================================================================
  // CONVERSATION MANAGEMENT (Phase 2)
  // ============================================================================

  @override
  Future<bool> acceptConversation(String topic) async {
    await _ensureInitialized();
    return rust_conversations.acceptConversation(topic: topic);
  }

  @override
  Future<bool> denyConversation(String topic) async {
    await _ensureInitialized();
    return rust_conversations.denyConversation(topic: topic);
  }

  @override
  Future<List<Map<String, dynamic>>> listConversations() async {
    await _ensureInitialized();
    final conversations = await rust_conversations.listConversations();
    return conversations.map(_conversationInfoToMap).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listDms({String? consentState}) async {
    await _ensureInitialized();
    final dms = await rust_conversations.listDms(consentState: consentState);
    return dms.map(_conversationInfoToMap).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listGroups({String? consentState}) async {
    await _ensureInitialized();
    final groups = await rust_conversations.listGroups(consentState: consentState);
    return groups.map(_conversationInfoToMap).toList();
  }

  @override
  Future<bool> canMessage(String address) async {
    await _ensureInitialized();
    return rust_conversations.canMessage(address: address);
  }

  @override
  Future<bool> canMessageByInboxId(String inboxId) async {
    await _ensureInitialized();
    final states = await rust_groups.inboxStatesForInboxIds(
      inboxIds: [inboxId],
      refreshFromNetwork: true,
    );
    if (states.isEmpty) return false;
    return states.first.installations.isNotEmpty;
  }

  @override
  Future<Map<String, dynamic>> findOrCreateDMWithInboxId(
      String inboxId) async {
    await _ensureInitialized();
    final dm = await rust_conversations.findOrCreateDmWithInboxId(
        inboxId: inboxId);
    return _conversationInfoToMap(dm);
  }

  @override
  Future<String> inboxIdFromAddress(String address) async {
    await _ensureInitialized();
    return rust_conversations.inboxIdFromAddress(address: address);
  }

  @override
  Future<String?> conversationTopicFromAddress(String peerAddress) async {
    await _ensureInitialized();
    return rust_conversations.conversationTopicFromAddress(
        address: peerAddress);
  }

  // ============================================================================
  // GROUP OPERATIONS (Phase 3)
  // ============================================================================

  @override
  Future<Map<String, dynamic>> newGroup(
      List<String> inboxIds, Map<String, String> options) async {
    await _ensureInitialized();
    final conv = await rust_groups.newGroup(
      inboxIds: inboxIds,
      name: options['name'],
      imageUrlSquare: options['imageUrl'],
      description: options['description'],
    );
    return _conversationInfoToMap(conv);
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupMembers(String topic) async {
    await _ensureInitialized();
    final members = await rust_groups.listGroupMembers(topic: topic);
    return members
        .map((m) => <dynamic, dynamic>{
              'inboxId': m.inboxId,
              'address': m.address,
            })
        .toList();
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupAdmins(String topic) async {
    await _ensureInitialized();
    final admins = await rust_groups.listGroupAdmins(topic: topic);
    return admins
        .map((id) => <dynamic, dynamic>{'inboxId': id})
        .toList();
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupSuperAdmins(
      String topic) async {
    await _ensureInitialized();
    final superAdmins = await rust_groups.listGroupSuperAdmins(topic: topic);
    return superAdmins
        .map((id) => <dynamic, dynamic>{'inboxId': id})
        .toList();
  }

  @override
  Future<bool> addGroupMembers(String topic, List<String> inboxIds) async {
    await _ensureInitialized();
    return rust_groups.addGroupMembers(topic: topic, inboxIds: inboxIds);
  }

  @override
  Future<bool> removeGroupMembers(String topic, List<String> inboxIds) async {
    await _ensureInitialized();
    return rust_groups.removeGroupMembers(topic: topic, inboxIds: inboxIds);
  }

  @override
  Future<bool> addGroupAdmin(String topic, String inboxId) async {
    await _ensureInitialized();
    return rust_groups.addGroupAdmin(topic: topic, inboxId: inboxId);
  }

  @override
  Future<bool> removeGroupAdmin(String topic, String inboxId) async {
    await _ensureInitialized();
    return rust_groups.removeGroupAdmin(topic: topic, inboxId: inboxId);
  }

  @override
  Future<bool> addGroupSuperAdmin(String topic, String inboxId) async {
    await _ensureInitialized();
    return rust_groups.addGroupSuperAdmin(topic: topic, inboxId: inboxId);
  }

  @override
  Future<bool> removeGroupSuperAdmin(String topic, String inboxId) async {
    await _ensureInitialized();
    return rust_groups.removeGroupSuperAdmin(topic: topic, inboxId: inboxId);
  }

  @override
  Future<bool> updateGroup(String topic, Map<String, String> updates) async {
    await _ensureInitialized();
    return rust_groups.updateGroup(
      topic: topic,
      name: updates['name'],
      description: updates['description'],
      imageUrl: updates['imageUrl'],
    );
  }

  @override
  Future<Map<String, dynamic>> getGroupMemberRole(
      String topic, String inboxId) async {
    await _ensureInitialized();
    final role = await rust_groups.getGroupMemberRole(
        topic: topic, inboxId: inboxId);
    return {
      'isAdmin': role.isAdmin,
      'isSuperAdmin': role.isSuperAdmin,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> inboxStatesForInboxIds(
      List<String> inboxIds,
      {bool refreshFromNetwork = true}) async {
    await _ensureInitialized();
    final states = await rust_groups.inboxStatesForInboxIds(
      inboxIds: inboxIds,
      refreshFromNetwork: refreshFromNetwork,
    );
    return states
        .map((state) => <String, dynamic>{
              'inboxId': state.inboxId,
              'identities': state.identities
                  .map((i) => {
                        'identifier': i.identifier,
                        'kind': i.kind,
                      })
                  .toList(),
              'installations': state.installations
                  .map((i) => {
                        'id': i.id,
                        'createdAt': i.createdAt,
                      })
                  .toList(),
              'recoveryIdentity': {
                'identifier': state.recoveryIdentity.identifier,
                'kind': state.recoveryIdentity.kind,
              },
            })
        .toList();
  }

  // ============================================================================
  // CONSENT MANAGEMENT (Phase 4)
  // ============================================================================

  @override
  Future<String> getConversationConsentState(String topic) async {
    await _ensureInitialized();
    return rust_consent.getConversationConsentState(topic: topic);
  }

  @override
  Future<bool> setConversationConsentState(String topic, String state) async {
    await _ensureInitialized();
    return rust_consent.setConversationConsentState(
        topic: topic, state: state);
  }

  @override
  Future<String> getInboxConsentState(String inboxId) async {
    await _ensureInitialized();
    return rust_consent.getInboxConsentState(inboxId: inboxId);
  }

  @override
  Future<bool> setInboxConsentState(String inboxId, String state) async {
    await _ensureInitialized();
    return rust_consent.setInboxConsentState(inboxId: inboxId, state: state);
  }

  @override
  Future<bool> syncConsentPreferences() async {
    await _ensureInitialized();
    return rust_consent.syncConsentPreferences();
  }

  // ============================================================================
  // SYNC & INBOX (Phase 5)
  // ============================================================================

  @override
  Future<Map<String, int>> syncAll({List<String> consentStates = const ['allowed']}) async {
    await _ensureInitialized();
    final numSynced = await rust_conversations.syncAll(consentStates: consentStates);
    return {'numGroupsSynced': numSynced};
  }

  @override
  Future<void> syncConversation(String topic) async {
    await _ensureInitialized();
    await rust_conversations.syncConversation(topic: topic);
  }

  @override
  Future<bool> sendSyncRequest() async {
    await _ensureInitialized();
    return rust_inbox.sendSyncRequest();
  }

  @override
  Future<String> getInstallationId() async {
    await _ensureInitialized();
    return rust_inbox.getInstallationId();
  }

  @override
  Future<Map<String, dynamic>> inboxState(
      {bool refreshFromNetwork = false}) async {
    await _ensureInitialized();
    final state =
        await rust_inbox.getInboxState(refreshFromNetwork: refreshFromNetwork);
    return <String, dynamic>{
      'inboxId': state.inboxId,
      'identities': state.identities
          .map((i) => {
                'identifier': i.identifier,
                'kind': i.kind,
              })
          .toList(),
      'installations': state.installations
          .map((i) => {
                'id': i.id,
                'createdAt': i.createdAt,
              })
          .toList(),
      'recoveryIdentity': {
        'identifier': state.recoveryIdentity.identifier,
        'kind': state.recoveryIdentity.kind,
      },
    };
  }

  @override
  Future<void> revokeInstallations(
      Uint8List signerPrivateKey, List<String> installationIds) async {
    await _ensureInitialized();
    await rust_signing.revokeInstallations(
      signerPrivateKey: signerPrivateKey.toList(),
      installationIds: installationIds,
    );
  }

  @override
  Future<void> revokeAllOtherInstallations(Uint8List signerPrivateKey) async {
    await _ensureInitialized();
    await rust_signing.revokeAllOtherInstallations(
      signerPrivateKey: signerPrivateKey.toList(),
    );
  }

  @override
  Future<void> addAccount(Uint8List newAccountPrivateKey,
      {bool allowReassignInboxId = false}) async {
    await _ensureInitialized();
    await rust_signing.addAccount(
      newAccountPrivateKey: newAccountPrivateKey.toList(),
    );
  }

  @override
  Future<void> removeAccount(
      Uint8List recoveryPrivateKey, String identifierToRemove) async {
    await _ensureInitialized();
    await rust_signing.removeAccount(
      recoveryPrivateKey: recoveryPrivateKey.toList(),
      identifierToRemove: identifierToRemove,
    );
  }

  // ============================================================================
  // STATIC OPERATIONS (no active client needed)
  // ============================================================================

  @override
  Future<void> staticRevokeInstallations(Uint8List signerPrivateKey,
      String inboxId, List<String> installationIds) async {
    await _ensureInitialized();
    await rust_signing.staticRevokeInstallations(
      signerPrivateKey: signerPrivateKey.toList(),
      inboxId: inboxId,
      installationIds: installationIds,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> staticInboxStatesForInboxIds(
      List<String> inboxIds) async {
    await _ensureInitialized();
    final states = await rust_signing.staticInboxStatesForInboxIds(
      inboxIds: inboxIds,
    );
    return states
        .map((state) => <String, dynamic>{
              'inboxId': state.inboxId,
              'identities': state.identities
                  .map((i) => {
                        'identifier': i.identifier,
                        'kind': i.kind,
                      })
                  .toList(),
              'installations': state.installations
                  .map((i) => {
                        'id': i.id,
                        'createdAt': i.createdAt,
                      })
                  .toList(),
              'recoveryIdentity': {
                'identifier': state.recoveryIdentity.identifier,
                'kind': state.recoveryIdentity.kind,
              },
            })
        .toList();
  }

  @override
  Future<String?> staticGetInboxIdForAddress(String address,
      {String environment = 'production'}) async {
    await _ensureInitialized();
    return await rust_client.staticGetInboxIdForAddress(
      address: address,
      environment: environment,
    );
  }

  @override
  Future<void> staticDeleteLocalDatabase(String address, String inboxId,
      {String environment = 'production'}) async {
    await _ensureInitialized();
    await rust_client.staticDeleteLocalDatabase(
      address: address,
    );
  }

  // ============================================================================
  // PRIVATE HELPERS — Convert typed FRB structs to Maps matching Android format
  // ============================================================================

  /// Convert a MessageInfo struct to a Map matching Android's message format.
  Map<String, dynamic> _messageInfoToMap(rust_messaging.MessageInfo msg) {
    // Decode body from protobuf bytes — Android provides this natively,
    // Windows must decode it here for parity.
    String? body;
    try {
      final encoded = proto.EncodedContent.fromBuffer(
          Uint8List.fromList(msg.encodedContentBytes));
      if (encoded.type.typeId == 'text') {
        body = utf8.decode(encoded.content);
      } else {
        // For unknown content types (e.g. coinbase.com/actions), prefer the
        // actual content bytes (they contain the structured data, e.g. JSON)
        // over the protobuf fallback field (a human-readable summary for
        // clients that don't support the content type). Android's SDK exposes
        // the content bytes as message.body for these types.
        try {
          body = utf8.decode(encoded.content);
        } catch (_) {
          if (encoded.hasFallback() && encoded.fallback.isNotEmpty) {
            body = encoded.fallback;
          }
        }
      }
    } catch (_) {}

    return {
      'id': msg.id,
      'sent': msg.sentAtMs,
      'senderInboxId': msg.senderInboxId,
      'conversationTopic': msg.conversationTopic,
      'encodedContent': msg.encodedContentBytes,
      'body': body,
      'members': msg.members
          .map((m) => {
                'inboxId': m.inboxId,
                'addresses': m.address,
              })
          .toList(),
    };
  }

  /// Convert a ConversationInfo struct to a Map matching Android's format.
  Map<String, dynamic> _conversationInfoToMap(
      rust_conversations.ConversationInfo conv) {
    final map = <String, dynamic>{
      'id': conv.id,
      'topic': conv.topic,
      'createdAt': conv.createdAtMs,
      'members': conv.members
          .map((m) => {
                'inboxId': m.inboxId,
                'addresses': m.address,
              })
          .toList(),
    };

    // DM-specific fields
    if (conv.peerInboxId != null) {
      map['peerInboxId'] = conv.peerInboxId;
    }

    // Group-specific fields
    if (conv.name != null) {
      map['name'] = conv.name;
    }
    if (conv.imageUrlSquare != null) {
      map['imageUrlSquare'] = conv.imageUrlSquare;
    }
    if (conv.description != null) {
      map['description'] = conv.description;
    }

    return map;
  }

  /// Build a serialized EncodedContent protobuf from the codec output.
  /// The message comes from the codec system as a Map with 'content' (bytes)
  /// and 'parameters' (Map<String, String>). We construct the full protobuf
  /// EncodedContent (matching what Android/iOS do) and serialize it for Rust.
  List<int> _extractContentBytes(
      dynamic message, String authorityId, String typeId, int versionMajor) {
    Uint8List contentBytes;
    Map<String, String> parameters = {};

    if (message is Map) {
      final content = message['content'];
      if (content is Uint8List) {
        contentBytes = content;
      } else if (content is List<int>) {
        contentBytes = Uint8List.fromList(content);
      } else {
        contentBytes = Uint8List.fromList(message.toString().codeUnits);
      }
      final params = message['parameters'];
      if (params is Map) {
        parameters = Map<String, String>.from(
            params.map((k, v) => MapEntry(k.toString(), v.toString())));
      }
    } else if (message is Uint8List) {
      contentBytes = message;
    } else if (message is List<int>) {
      contentBytes = Uint8List.fromList(message);
    } else {
      contentBytes = Uint8List.fromList(message.toString().codeUnits);
    }

    // Build the EncodedContent protobuf (same as Android's EncodedContent.newBuilder())
    final encodedContent = proto.EncodedContent(
      type: proto.ContentTypeId(
        authorityId: authorityId,
        typeId: typeId,
        versionMajor: versionMajor,
      ),
      content: contentBytes,
      parameters: parameters.entries,
    );

    return encodedContent.writeToBuffer();
  }
}
