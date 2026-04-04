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

  Future<String?> initializeClient(Uint8List privateKey, Uint8List dbKey, {String environment = 'production'}) {
    throw UnimplementedError('initializeClient() has not been implemented.');
  }

  Future<String?> getClientAddress() {
    throw UnimplementedError('getClientAddress() has not been implemented.');
  }

  Future<String?> getClientInboxId() {
    throw UnimplementedError('getClientInboxId() has not been implemented.');
  }

  Future<String?> sendMessage(String recipientAddress, dynamic message, String authorityId, String typeId, int versionMajor) {
    throw UnimplementedError('sendMessage() has not been implemented.');
  }

  Future<String?> sendMessageByInboxId(String recipientInboxId, dynamic message, String authorityId, String typeId, int versionMajor) {
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

  Future<void> changeRecoveryIdentifier(Uint8List signerPrivateKey, String newRecoveryIdentifier) {
    throw UnimplementedError('changeRecoveryIdentifier() has not been implemented.');
  }
}
