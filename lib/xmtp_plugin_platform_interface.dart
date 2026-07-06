import 'dart:typed_data';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'xmtp_plugin_method_channel.dart';

abstract class XmtpPluginPlatform extends PlatformInterface {
  /// Constructs a XmtpPluginPlatform.
  XmtpPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static XmtpPluginPlatform _instance = MethodChannelXmtpPlugin();

  /// The default instance of [XmtpPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelXmtpPlugin].
  static XmtpPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XmtpPluginPlatform] when
  /// they register themselves.
  static set instance(XmtpPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Uint8List> generatePrivateKey() {
    throw UnimplementedError('generatePrivateKey() has not been implemented.');
  }

  Future<String?> initializeClient(Uint8List privateKey, Uint8List dbKey,
      {String environment = 'production', String? dbDirectory}) {
    throw UnimplementedError('initializeClient() has not been implemented.');
  }

  Future<bool> closeClient() {
    throw UnimplementedError('closeClient() has not been implemented.');
  }

  Future<bool> staticLocalDatabaseExists(String address,
      {String? inboxId, String environment = 'production', String? dbDirectory}) {
    throw UnimplementedError('staticLocalDatabaseExists() has not been implemented.');
  }

  Future<void> staticExportLocalDatabase(String destPath, String address,
      {String? inboxId, String environment = 'production', String? dbDirectory}) {
    throw UnimplementedError('staticExportLocalDatabase() has not been implemented.');
  }

  Future<void> staticImportLocalDatabase(String sourcePath, String address,
      {String? inboxId, String environment = 'production', String? dbDirectory}) {
    throw UnimplementedError('staticImportLocalDatabase() has not been implemented.');
  }

  Future<String?> getClientAddress() {
    throw UnimplementedError('getClientAddress() has not been implemented.');
  }

  Future<String?> getClientInboxId() {
    throw UnimplementedError('getClientInboxId() has not been implemented.');
  }

  // ============================================================================
  // ARCHIVE BACKUP (native libxmtp encrypted archive export/import)
  // `key` is the 32-byte archive key, derived in the facade (Argon2id). The
  // platform layer never sees the password.
  // ============================================================================

  Future<void> createArchive(String path, Uint8List key,
      {List<String> elements = const [], int? startNs, int? endNs, bool excludeDisappearing = false}) {
    throw UnimplementedError('createArchive() has not been implemented.');
  }

  Future<void> importArchive(String path, Uint8List key) {
    throw UnimplementedError('importArchive() has not been implemented.');
  }

  Future<Map<String, dynamic>> archiveMetadata(String path, Uint8List key) {
    throw UnimplementedError('archiveMetadata() has not been implemented.');
  }

  Future<String?> sendMessage(String recipientAddress, dynamic message, String authorityId, String typeId, int versionMajor) {
    throw UnimplementedError('sendMessage() has not been implemented.');
  }

  /// Returns a map with `messageId` and the live DM `topic` (the conversation
  /// that was actually sent to — send is find-or-create, so this is always the
  /// canonical DM topic). `topic` may be null on platforms that don't surface it.
  Future<Map<String, dynamic>?> sendMessageByInboxId(String recipientInboxId, dynamic message, String authorityId, String typeId, int versionMajor) {
    throw UnimplementedError('sendMessageByInboxId() has not been implemented.');
  }

  Future<String?> sendGroupMessage(String topic, dynamic message, String authorityId, String typeId, int versionMajor) {
    throw UnimplementedError('sendGroupMessage() has not been implemented.');
  }

  Future<Map<String, dynamic>> loadRemoteAttachment(Map<String, dynamic> params) async {
    throw UnimplementedError('loadRemoteAttachment() has not been implemented.');
  }

  Stream<Map<String, dynamic>> subscribeToAllMessages() {
    throw UnimplementedError('subscribeToAllMessages() has not been implemented.');
  }

  /// Stop the *native* incoming-message stream loop.
  ///
  /// Default is a deliberate no-op: on Windows/Web the native stream stops the
  /// moment the Dart subscription is cancelled (FRB drops the future / JS
  /// callback is released), so there is nothing extra to do. Android and iOS
  /// run the stream as a fire-and-forget coroutine/Task that the Dart-side
  /// cancel does NOT reach, so they override this to cancel it explicitly.
  Future<void> stopMessageStream() async {
    // no-op by default — see doc comment above.
  }

  Future<List<Map<String, dynamic>>> getMessagesAfterDate(String peerAddress, DateTime fromDate) {
    throw UnimplementedError('getMessagesAfterDate() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getMessagesAfterDateByTopic(String topic, DateTime fromDate) {
    throw UnimplementedError('getMessagesAfterDateByTopic() has not been implemented.');
  }

  Future<bool> acceptConversation(String topic) {
    throw UnimplementedError('acceptConversation() has not been implemented.');
  }

  Future<bool> denyConversation(String topic) {
    throw UnimplementedError('denyConversation() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> listConversations() {
    throw UnimplementedError('listConversations() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> listDms({String? consentState}) {
    throw UnimplementedError('listDms() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> listGroups({String? consentState}) {
    throw UnimplementedError('listGroups() has not been implemented.');
  }

  Future<bool> canMessage(String address) {
    throw UnimplementedError('canMessage() has not been implemented.');
  }

  Future<bool> canMessageByInboxId(String inboxId) {
    throw UnimplementedError('canMessageByInboxId() has not been implemented.');
  }

  Future<Map<String, dynamic>> findOrCreateDMWithInboxId(String inboxId) {
    throw UnimplementedError('findOrCreateDMWithInboxId() has not been implemented.');
  }

  Future<String> inboxIdFromAddress(String address) {
    throw UnimplementedError('inboxIdFromAddress() has not been implemented.');
  }

  Future<String?> conversationTopicFromAddress(String peerAddress) {
    throw UnimplementedError('conversationTopicFromAddress() has not been implemented.');
  }

  Future<Map<String, dynamic>> newGroup(List<String> inboxIds, Map<String, String> options) {
    throw UnimplementedError('newGroup() has not been implemented.');
  }

  Future<List<Map<dynamic, dynamic>>> listGroupMembers(String topic) {
    throw UnimplementedError('listGroupMembers() has not been implemented.');
  }

  Future<List<Map<dynamic, dynamic>>> listGroupAdmins(String topic) {
    throw UnimplementedError('listGroupAdmins() has not been implemented.');
  }

  Future<List<Map<dynamic, dynamic>>> listGroupSuperAdmins(String topic) {
    throw UnimplementedError('listGroupSuperAdmins() has not been implemented.');
  }

  Future<bool> addGroupMembers(String topic, List<String> inboxIds) {
    throw UnimplementedError('addGroupMembers() has not been implemented.');
  }

  Future<bool> removeGroupMembers(String topic, List<String> inboxIds) {
    throw UnimplementedError('removeGroupMembers() has not been implemented.');
  }

  Future<bool> addGroupAdmin(String topic, String inboxId) {
    throw UnimplementedError('addGroupAdmin() has not been implemented.');
  }

  Future<bool> removeGroupAdmin(String topic, String inboxId) {
    throw UnimplementedError('removeGroupAdmin() has not been implemented.');
  }

  Future<bool> addGroupSuperAdmin(String topic, String inboxId) {
    throw UnimplementedError('addGroupSuperAdmin() has not been implemented.');
  }

  Future<bool> removeGroupSuperAdmin(String topic, String inboxId) {
    throw UnimplementedError('removeGroupSuperAdmin() has not been implemented.');
  }

  Future<bool> updateGroup(String topic, Map<String, String> updates) {
    throw UnimplementedError('updateGroup() has not been implemented.');
  }

  Future<Map<String, dynamic>> getGroupMemberRole(String topic, String inboxId) {
    throw UnimplementedError('getGroupMemberRole() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> inboxStatesForInboxIds(List<String> inboxIds, {bool refreshFromNetwork = true}) {
    throw UnimplementedError('inboxStatesForInboxIds() has not been implemented.');
  }

  // ============================================================================
  // CONSENT MANAGEMENT
  // ============================================================================

  Future<String> getConversationConsentState(String topic) {
    throw UnimplementedError('getConversationConsentState() has not been implemented.');
  }

  Future<bool> setConversationConsentState(String topic, String state) {
    throw UnimplementedError('setConversationConsentState() has not been implemented.');
  }

  Future<String> getInboxConsentState(String inboxId) {
    throw UnimplementedError('getInboxConsentState() has not been implemented.');
  }

  Future<bool> setInboxConsentState(String inboxId, String state) {
    throw UnimplementedError('setInboxConsentState() has not been implemented.');
  }

  Future<bool> syncConsentPreferences() {
    throw UnimplementedError('syncConsentPreferences() has not been implemented.');
  }

  // ============================================================================
  // SYNC & INBOX
  // ============================================================================

  Future<bool> sendSyncRequest() {
    throw UnimplementedError('sendSyncRequest() has not been implemented.');
  }

  Future<Map<String, int>> syncAll({List<String> consentStates = const ['allowed']}) {
    throw UnimplementedError('syncAll() has not been implemented.');
  }

  Future<void> syncConversation(String topic) {
    throw UnimplementedError('syncConversation() has not been implemented.');
  }

  Future<String> getInstallationId() {
    throw UnimplementedError('getInstallationId() has not been implemented.');
  }

  Future<Map<String, dynamic>> inboxState({bool refreshFromNetwork = false}) {
    throw UnimplementedError('inboxState() has not been implemented.');
  }

  Future<void> revokeInstallations(Uint8List signerPrivateKey, List<String> installationIds) {
    throw UnimplementedError('revokeInstallations() has not been implemented.');
  }

  Future<void> revokeAllOtherInstallations(Uint8List signerPrivateKey) {
    throw UnimplementedError('revokeAllOtherInstallations() has not been implemented.');
  }

  Future<void> addAccount(Uint8List newAccountPrivateKey, {bool allowReassignInboxId = false}) {
    throw UnimplementedError('addAccount() has not been implemented.');
  }

  Future<void> removeAccount(Uint8List recoveryPrivateKey, String identifierToRemove) {
    throw UnimplementedError('removeAccount() has not been implemented.');
  }

  // ============================================================================
  // STATIC OPERATIONS (no active client needed)
  // ============================================================================

  Future<void> staticRevokeInstallations(Uint8List signerPrivateKey, String inboxId, List<String> installationIds) {
    throw UnimplementedError('staticRevokeInstallations() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> staticInboxStatesForInboxIds(List<String> inboxIds) {
    throw UnimplementedError('staticInboxStatesForInboxIds() has not been implemented.');
  }

  Future<String?> staticGetInboxIdForAddress(String address, {String environment = 'production'}) {
    throw UnimplementedError('staticGetInboxIdForAddress() has not been implemented.');
  }

  Future<void> staticDeleteLocalDatabase(String address, String inboxId, {String environment = 'production', String? dbDirectory}) {
    throw UnimplementedError('staticDeleteLocalDatabase() has not been implemented.');
  }

  Future<void> changeRecoveryIdentifier(Uint8List signerPrivateKey, String newRecoveryIdentifier) {
    throw UnimplementedError('changeRecoveryIdentifier() has not been implemented.');
  }

  // ============================================================================
  // PUSH NOTIFICATIONS (subscription registration + push-arrival decryption)
  // ============================================================================

  /// Aggregate HMAC keys for every conversation the client knows about (including
  /// stitched duplicate DMs). Each entry: `{topic: String, hmacKey: Uint8List,
  /// thirtyDayPeriodsSinceEpoch: int}`. libxmtp returns 3 keys per conversation
  /// (prior / current / next epoch). Feed these to the notif server's
  /// `subscribeWithMetadata` so it can filter listener traffic without breaking E2E.
  Future<List<Map<String, dynamic>>> getAllHmacKeys() {
    throw UnimplementedError('getAllHmacKeys() has not been implemented.');
  }

  /// Decrypt an FCM/APNs push payload for an existing conversation (looked up by topic).
  /// Returns a list of decoded messages — usually 1, occasionally more if the
  /// envelope contained multiple. Each entry mirrors `getMessagesAfterDate` shape.
  Future<List<Map<String, dynamic>>> processPushMessage(String topic, Uint8List encryptedBytes) {
    throw UnimplementedError('processPushMessage() has not been implemented.');
  }

  /// Decrypt an FCM/APNs push payload that arrived on the welcome topic
  /// (`/xmtp/mls/1/w-${installationId}/proto`). Returns the newly-created
  /// conversation(s) — usually 1, occasionally more from DM stitching.
  /// Each entry mirrors `listConversations` shape.
  Future<List<Map<String, dynamic>>> processWelcome(Uint8List encryptedBytes) {
    throw UnimplementedError('processWelcome() has not been implemented.');
  }
}
