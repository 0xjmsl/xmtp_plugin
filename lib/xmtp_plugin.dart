import 'dart:async';
import 'dart:typed_data';
import 'package:xmtp_plugin/codecs.dart';
import 'xmtp_plugin_platform_interface.dart';

// Conditionally export the Windows FFI implementation only on platforms
// that support dart:ffi. On web (dart:js_interop available) and platforms
// without dart:ffi, export a stub to avoid compiling Rust/FFI bindings.
export 'xmtp_plugin_windows.dart'
    if (dart.library.js_interop) 'xmtp_plugin_windows_stub.dart';

class XmtpPlugin {
  final XMTPCodecRegistry _codecRegistry = XMTPCodecRegistry();

  XmtpPluginPlatform get _platform => XmtpPluginPlatform.instance;

  void registerCodec(XMTPCodec codec) {
    _codecRegistry.registerCodec(codec);
  }

  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  Future<Uint8List> generatePrivateKey() async {
    return _platform.generatePrivateKey();
  }

  /// Initialize the XMTP client.
  ///
  /// [dbDirectory] (iOS only, optional): override the XMTPiOS DB directory.
  /// Pass an App Group container path here when sharing the installation DB
  /// with a Notification Service Extension. Defaults to XMTPiOS's app-scope
  /// location when null. Ignored on Android/Web/Windows.
  Future<String?> initializeClient(Uint8List privateKey, Uint8List dbKey,
      {String environment = 'production', String? dbDirectory}) async {
    final String? address = await _platform.initializeClient(privateKey, dbKey,
        environment: environment, dbDirectory: dbDirectory);
    // Register built-in codecs
    _codecRegistry.registerCodec(TextCodec());
    _codecRegistry.registerCodec(ReplyCodec(_codecRegistry));
    _codecRegistry.registerCodec(ReadReceiptCodec());
    _codecRegistry.registerCodec(TransactionReferenceCodec());
    _codecRegistry.registerCodec(DeleteMessageCodec());
    _codecRegistry.registerCodec(LeaveRequestCodec());
    _codecRegistry.registerCodec(MultiRemoteAttachmentCodec());
    return address;
  }

  Future<String> getClientAddress() async {
    final String? clientAddress = await _platform.getClientAddress();
    return clientAddress ?? '';
  }

  Future<String> getClientInboxId() async {
    final String? clientInboxId = await _platform.getClientInboxId();
    return clientInboxId ?? '';
  }

  Future<String?> sendMessage(String recipientAddress, dynamic content, String authorityId, String typeId) async {
    final codec = _codecRegistry.getCodec(authorityId, typeId);
    if (codec == null) {
      throw Exception('No codec found for $authorityId/$typeId');
    }

    final messageMap = await codec.encode(content);

    return _platform.sendMessage(
      recipientAddress,
      messageMap,
      authorityId,
      typeId,
      codec.versionMajor,
    );
  }

  /// Sends a DM by recipient inbox id and returns `{messageId, topic}` where
  /// `topic` is the live DM the message was sent to (find-or-create). Callers
  /// use `topic` to heal a stale cached conversation topic.
  Future<Map<String, dynamic>?> sendMessageByInboxId(String recipientInboxId, dynamic content, String authorityId, String typeId) async {
    final codec = _codecRegistry.getCodec(authorityId, typeId);
    if (codec == null) {
      throw Exception('No codec found for $authorityId/$typeId');
    }

    final messageMap = await codec.encode(content);

    return _platform.sendMessageByInboxId(
      recipientInboxId,
      messageMap,
      authorityId,
      typeId,
      codec.versionMajor,
    );
  }

  Future<String?> sendGroupMessage(String topic, dynamic content, String authorityId, String typeId) async {
    final codec = _codecRegistry.getCodec(authorityId, typeId);
    if (codec == null) {
      throw Exception('No codec found for $authorityId/$typeId');
    }

    final messageMap = await codec.encode(content);

    return _platform.sendGroupMessage(
      topic,
      messageMap,
      authorityId,
      typeId,
      codec.versionMajor,
    );
  }

  Stream<Map<String, dynamic>> subscribeToAllMessages() {
    final controller = StreamController<Map<String, dynamic>>();
    final rawStream = _platform.subscribeToAllMessages();

    rawStream.listen(
      (message) async {
        // Deserialize encodedContent from protobuf bytes (web returns List<dynamic>, native returns Uint8List)
        final rawEncoded = message['encodedContent'];
        final Uint8List? encodedContentBytes = rawEncoded is Uint8List
            ? rawEncoded
            : rawEncoded is List
                ? Uint8List.fromList(List<int>.from(rawEncoded))
                : null;
        if (encodedContentBytes != null) {
          try {
            final encodedContent = EncodedContent.fromBuffer(encodedContentBytes);
            print('Content type: ${encodedContent.type.authorityId}/${encodedContent.type.typeId}');

            final codec = _codecRegistry.getCodec(
              encodedContent.type.authorityId,
              encodedContent.type.typeId
            );
            print('Codec found: $codec');

            if (codec != null) {
              dynamic decodedContent = await codec.decode(encodedContent);
              print('Decoded content: $decodedContent');

              if (codec is AttachmentCodec && decodedContent is AttachmentContent) {
                decodedContent = AttachmentContent(
                  data: decodedContent.data,
                  filename: encodedContent.parameters['filename'] ?? decodedContent.filename,
                  mimeType: encodedContent.parameters['mimeType'] ?? decodedContent.mimeType,
                  description: decodedContent.description,
                );
                print('Attachment content updated with parameters: $decodedContent');
              }
              print('Final decoded content: $decodedContent');
              message['decodedContent'] = decodedContent;
            } else {
              print('No codec found for content type: ${encodedContent.type.authorityId}/${encodedContent.type.typeId}');
            }
          } catch (e) {
            print('Failed to decode message: $e');
          }
        }

        controller.add(message);
      },
      onError: (e) => controller.addError(e),
      onDone: () => controller.close(),
    );

    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> getMessagesAfterDate(String peerAddress, DateTime fromDate) async {
    final result = await _platform.getMessagesAfterDate(peerAddress, fromDate);
    return await _processMessages(result);
  }

  Future<List<Map<String, dynamic>>> getMessagesAfterDateByTopic(String topic, DateTime fromDate) async {
    final result = await _platform.getMessagesAfterDateByTopic(topic, fromDate);
    return await _processMessages(result);
  }

  // Helper method to process messages with codecs
  Future<List<Map<String, dynamic>>> _processMessages(List<Map<String, dynamic>> messages) async {
    final processedMessages = <Map<String, dynamic>>[];

    for (final messageMap in messages) {
      final rawEncoded = messageMap['encodedContent'];
      final Uint8List? encodedContentBytes = rawEncoded is Uint8List
          ? rawEncoded
          : rawEncoded is List
              ? Uint8List.fromList(List<int>.from(rawEncoded))
              : null;

      if (encodedContentBytes != null) {
        try {
          final encodedContent = EncodedContent.fromBuffer(encodedContentBytes);
          final codec = _codecRegistry.getCodec(
            encodedContent.type.authorityId,
            encodedContent.type.typeId
          );
          print('Processing message with content type: ${encodedContent.type.authorityId}/${encodedContent.type.typeId}, codec: $codec');

          if (codec != null) {
            dynamic decodedContent = await codec.decode(encodedContent);
            print('Decoded content before adjustments: $decodedContent');

            if (codec is AttachmentCodec && decodedContent is AttachmentContent) {
              decodedContent = AttachmentContent(
                data: decodedContent.data,
                filename: encodedContent.parameters['filename'] ?? decodedContent.filename,
                mimeType: encodedContent.parameters['mimeType'] ?? decodedContent.mimeType,
                description: decodedContent.description,
              );
            }

            messageMap['decodedContent'] = decodedContent;
            print('Decoded content: ${messageMap['decodedContent']}');
          }
        } catch (e) {
          print('Failed to decode message: $e');
        }
      }

      processedMessages.add(messageMap);
    }

    return processedMessages;
  }

  Future<AttachmentContent> loadRemoteAttachment({
    required String url,
    required String contentDigest,
    required Uint8List secret,
    required Uint8List salt,
    required Uint8List nonce,
    required String scheme,
    required int? contentLength,
    required String? filename,
  }) async {
    try {
      final params = {
        'url': url,
        'contentDigest': contentDigest,
        'secret': secret.toList(),
        'salt': salt.toList(),
        'nonce': nonce.toList(),
        'scheme': scheme,
        'contentLength': contentLength,
        'filename': filename,
      };

      final result = await _platform.loadRemoteAttachment(params);

      return AttachmentContent(
        filename: result['filename'] as String,
        mimeType: result['mimeType'] as String,
        data: result['data'] is Uint8List ? result['data'] as Uint8List : Uint8List.fromList(List<int>.from(result['data'])),
      );
    } catch (e) {
      throw Exception('Error loading remote attachment: $e');
    }
  }

  XMTPCodec? getCodec(String authorityId, String typeId) {
    return _codecRegistry.getCodec(authorityId, typeId);
  }

  // Consent Management Methods
  Future<String> getConversationConsentState(String topic) async {
    return _platform.getConversationConsentState(topic);
  }

  Future<bool> setConversationConsentState(String topic, String state) async {
    return _platform.setConversationConsentState(topic, state);
  }

  Future<String> getInboxConsentState(String inboxId) async {
    return _platform.getInboxConsentState(inboxId);
  }

  Future<bool> setInboxConsentState(String inboxId, String state) async {
    return _platform.setInboxConsentState(inboxId, state);
  }

  Future<bool> syncConsentPreferences() async {
    return _platform.syncConsentPreferences();
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final List<Map<String, dynamic>> result = await _platform.listConversations();

    return result.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<bool> sendSyncRequest() async {
    return _platform.sendSyncRequest();
  }

  Future<Map<String, int>> syncAll({List<String> consentStates = const ['allowed']}) async {
    return _platform.syncAll(consentStates: consentStates);
  }

  Future<void> syncConversation(String topic) async {
    return _platform.syncConversation(topic);
  }

  Future<List<Map<String, dynamic>>> listDms({String? consentState}) async {
    final List<Map<String, dynamic>> result = await _platform.listDms(consentState: consentState);

    return result.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<List<Map<String, dynamic>>> listGroups({String? consentState}) async {
    final List<Map<String, dynamic>> result = await _platform.listGroups(consentState: consentState);

    return result.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<Map<String, dynamic>> newGroup(List<String> inboxIds, Map<String, String> options) async {
    final result = await _platform.newGroup(inboxIds, options);
    return Map<String, dynamic>.from(result);
  }

  Future<bool> canMessageByAddress(String address) async {
    return _platform.canMessage(address);
  }

  Future<bool> canMessageByInboxId(String inboxId) async {
    return _platform.canMessageByInboxId(inboxId);
  }

  Future<Map<String, dynamic>> findOrCreateDMWithInboxId(String inboxId) async {
    final result = await _platform.findOrCreateDMWithInboxId(inboxId);
    return Map<String, dynamic>.from(result);
  }

  Future<String?> inboxIdFromAddress(String address) async {
    return _platform.inboxIdFromAddress(address);
  }

  Future<String?> conversationTopicFromAddress(String peerAddress) async {
    return _platform.conversationTopicFromAddress(peerAddress);
  }

  Future<List<Map<dynamic, dynamic>>> listGroupMembers(String topic) async {
    return _platform.listGroupMembers(topic);
  }

  Future<List<Map<dynamic, dynamic>>> listGroupAdmins(String topic) async {
    return _platform.listGroupAdmins(topic);
  }

  Future<List<Map<dynamic, dynamic>>> listGroupSuperAdmins(String topic) async {
    return _platform.listGroupSuperAdmins(topic);
  }

  Future<bool> addGroupMembers(String topic, List<String> inboxIds) async {
    return _platform.addGroupMembers(topic, inboxIds);
  }

  Future<bool> removeGroupMembers(String topic, List<String> inboxIds) async {
    return _platform.removeGroupMembers(topic, inboxIds);
  }

  Future<bool> addGroupAdmin(String topic, String inboxId) async {
    return _platform.addGroupAdmin(topic, inboxId);
  }

  Future<bool> removeGroupAdmin(String topic, String inboxId) async {
    return _platform.removeGroupAdmin(topic, inboxId);
  }

  Future<bool> addGroupSuperAdmin(String topic, String inboxId) async {
    return _platform.addGroupSuperAdmin(topic, inboxId);
  }

  Future<bool> removeGroupSuperAdmin(String topic, String inboxId) async {
    return _platform.removeGroupSuperAdmin(topic, inboxId);
  }

  Future<bool> updateGroup(String topic, Map<String, String> updates) async {
    return _platform.updateGroup(topic, updates);
  }

  Future<Map<String, dynamic>> getGroupMemberRole(String topic, String inboxId) async {
    return _platform.getGroupMemberRole(topic, inboxId);
  }

  Future<List<Map<String, dynamic>>> inboxStatesForInboxIds(List<String> inboxIds, {bool refreshFromNetwork = false}) async {
    return _platform.inboxStatesForInboxIds(inboxIds, refreshFromNetwork: refreshFromNetwork);
  }

  // ============================================================================
  // INBOX MANAGEMENT METHODS
  // ============================================================================

  Future<String> getInstallationId() async {
    return _platform.getInstallationId();
  }

  Future<Map<String, dynamic>> inboxState({bool refreshFromNetwork = false}) async {
    return _platform.inboxState(refreshFromNetwork: refreshFromNetwork);
  }

  Future<void> revokeInstallations(Uint8List signerPrivateKey, List<String> installationIds) async {
    return _platform.revokeInstallations(signerPrivateKey, installationIds);
  }

  Future<void> revokeAllOtherInstallations(Uint8List signerPrivateKey) async {
    return _platform.revokeAllOtherInstallations(signerPrivateKey);
  }

  Future<void> addAccount(Uint8List newAccountPrivateKey, {bool allowReassignInboxId = false}) async {
    return _platform.addAccount(newAccountPrivateKey, allowReassignInboxId: allowReassignInboxId);
  }

  Future<void> removeAccount(Uint8List recoveryPrivateKey, String identifierToRemove) async {
    return _platform.removeAccount(recoveryPrivateKey, identifierToRemove);
  }

  static Future<void> staticRevokeInstallations({
    required Uint8List signerPrivateKey,
    required String inboxId,
    required List<String> installationIds,
  }) async {
    return XmtpPluginPlatform.instance.staticRevokeInstallations(signerPrivateKey, inboxId, installationIds);
  }

  static Future<List<Map<String, dynamic>>> staticInboxStatesForInboxIds(
    List<String> inboxIds,
  ) async {
    return XmtpPluginPlatform.instance.staticInboxStatesForInboxIds(inboxIds);
  }

  /// Look up the real XMTP inbox ID for an Ethereum address from the network.
  /// Handles linked accounts (keys added to another inbox via `addAccount`).
  /// Returns null if the address has no inbox on the network.
  /// Does NOT require an initialized client.
  static Future<String?> staticGetInboxIdForAddress(
    String address, {
    String environment = 'production',
  }) async {
    return XmtpPluginPlatform.instance.staticGetInboxIdForAddress(address, environment: environment);
  }

  /// Delete the local XMTP database files for a given address/inboxId.
  /// Each platform uses the parameters it needs to construct the DB path.
  /// Does NOT require an initialized client.
  ///
  /// [dbDirectory] MUST match the value passed to [initializeClient] for this
  /// identity. On iOS the SDK stores the DB at
  /// `<dbDirectory ?? Documents>/xmtp-<env>-<inboxId>.db3`; if the client was
  /// opened with a custom directory (e.g. an App Group container shared with a
  /// Notification Service Extension) the delete MUST target that same
  /// directory or it silently removes nothing and a wrong-key DB survives.
  /// Ignored on Android (the DB always lives under the app's files dir).
  static Future<void> staticDeleteLocalDatabase(
    String address,
    String inboxId, {
    String environment = 'production',
    String? dbDirectory,
  }) async {
    return XmtpPluginPlatform.instance.staticDeleteLocalDatabase(address, inboxId,
        environment: environment, dbDirectory: dbDirectory);
  }

  Future<void> changeRecoveryIdentifier(Uint8List signerPrivateKey, String newRecoveryIdentifier) async {
    return _platform.changeRecoveryIdentifier(signerPrivateKey, newRecoveryIdentifier);
  }

  // ============================================================================
  // PUSH NOTIFICATIONS
  // ============================================================================

  /// Aggregate HMAC keys for every conversation the client knows about
  /// (including stitched duplicate DMs). Each entry has the topic in full
  /// XMTP wire format (`/xmtp/mls/1/g-${hex}/proto`), the HMAC key bytes, and
  /// the 30-day epoch counter. libxmtp returns three entries per conversation
  /// (prior epoch, current, next).
  ///
  /// Most consumers want [getAllPushTopics] instead — it groups these into
  /// one subscription per topic with all three HMAC keys attached, plus the
  /// welcome topic, in the exact shape the notification server expects.
  Future<List<PushHmacKeyEntry>> getAllHmacKeys() async {
    final raw = await _platform.getAllHmacKeys();
    return raw
        .map((m) => PushHmacKeyEntry(
              topic: m['topic'] as String,
              hmacKey: m['hmacKey'] is Uint8List
                  ? m['hmacKey'] as Uint8List
                  : Uint8List.fromList(List<int>.from(m['hmacKey'] as List)),
              thirtyDayPeriodsSinceEpoch:
                  (m['thirtyDayPeriodsSinceEpoch'] as num).toInt(),
            ))
        .toList();
  }

  /// Compute this installation's welcome topic, the per-installation topic
  /// that carries push notifications for brand-new conversations from
  /// previously-unknown senders. Format: `/xmtp/mls/1/w-${installationId}/proto`.
  Future<String> getWelcomeTopic() async {
    final id = await _platform.getInstallationId();
    return '/xmtp/mls/1/w-$id/proto';
  }

  /// All push subscriptions for this client, ready to register with the
  /// notification server's `subscribeWithMetadata` endpoint. One
  /// [PushSubscription] per conversation topic plus one for the welcome
  /// topic (which has no HMAC keys — welcome envelopes are decrypted via
  /// [processWelcome] rather than HMAC-matched).
  ///
  /// Topics are in full XMTP wire format throughout.
  Future<List<PushSubscription>> getAllPushTopics() async {
    final entries = await getAllHmacKeys();
    final grouped = <String, List<PushHmacKey>>{};
    for (final e in entries) {
      grouped
          .putIfAbsent(e.topic, () => [])
          .add(PushHmacKey(
            key: e.hmacKey,
            thirtyDayPeriodsSinceEpoch: e.thirtyDayPeriodsSinceEpoch,
          ));
    }
    final subs = grouped.entries
        .map((kv) => PushSubscription(topic: kv.key, hmacKeys: kv.value))
        .toList();
    subs.add(PushSubscription(topic: await getWelcomeTopic(), hmacKeys: const []));
    return subs;
  }

  /// Decrypt an FCM/APNs push payload for an existing conversation. `topic`
  /// is in full XMTP wire format (the value from the push payload's `topic`
  /// field). Returns a list of decoded messages — usually 1, occasionally
  /// more if the envelope contained multiple, and empty if it contained no
  /// application content (commit-only, etc.).
  Future<List<Map<String, dynamic>>> processPushMessage(
      String topic, Uint8List encryptedBytes) async {
    final result = await _platform.processPushMessage(topic, encryptedBytes);
    return _processMessages(result.map((e) => Map<String, dynamic>.from(e)).toList());
  }

  /// Decrypt an FCM/APNs push payload that arrived on the welcome topic.
  /// Creates the new conversation(s) in the local store and returns them —
  /// usually 1, occasionally more from DM stitching (Rust path only; Android
  /// and iOS surface a single conversation).
  Future<List<Map<String, dynamic>>> processWelcome(Uint8List encryptedBytes) async {
    final result = await _platform.processWelcome(encryptedBytes);
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

// ============================================================================
// PUSH NOTIFICATION DATA CLASSES
// ============================================================================

/// One HMAC key for one conversation topic, valid for a 30-day epoch window.
/// libxmtp returns three (prior / current / next) per topic so push delivery
/// keeps matching across the epoch boundary without re-subscribing.
class PushHmacKey {
  final Uint8List key;
  final int thirtyDayPeriodsSinceEpoch;

  const PushHmacKey({
    required this.key,
    required this.thirtyDayPeriodsSinceEpoch,
  });
}

/// One subscription entry as the XMTP notification server's
/// `subscribeWithMetadata` expects. [topic] is in full XMTP wire format
/// (`/xmtp/mls/1/g-${hex}/proto` for groups/DMs, `/xmtp/mls/1/w-${id}/proto`
/// for the welcome topic). [hmacKeys] is empty for the welcome topic.
class PushSubscription {
  final String topic;
  final List<PushHmacKey> hmacKeys;

  const PushSubscription({
    required this.topic,
    required this.hmacKeys,
  });
}

/// Flat HMAC-key entry returned by [XmtpPlugin.getAllHmacKeys]. Most consumers
/// should use [XmtpPlugin.getAllPushTopics] instead, which groups these into
/// the [PushSubscription] shape ready for the notification server.
class PushHmacKeyEntry {
  final String topic;
  final Uint8List hmacKey;
  final int thirtyDayPeriodsSinceEpoch;

  const PushHmacKeyEntry({
    required this.topic,
    required this.hmacKey,
    required this.thirtyDayPeriodsSinceEpoch,
  });
}
