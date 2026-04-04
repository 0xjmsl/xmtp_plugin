import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'xmtp_plugin_platform_interface.dart';

/// Web implementation of the XMTP Flutter plugin.
///
/// This implementation uses the XMTP Browser SDK v5 through JavaScript interop.
class XmtpPluginWeb extends XmtpPluginPlatform {
  /// Factory constructor that returns the singleton instance.
  static void registerWith(Registrar registrar) {
    XmtpPluginPlatform.instance = XmtpPluginWeb();
  }

  /// Reference to the JavaScript XMTP client manager.
  XMTPClientManager get _clientManager =>
      globalContext.getProperty('xmtpClientManager'.toJS) as XMTPClientManager;

  /// Stream controller for message subscriptions.
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  XmtpPluginWeb() {
    _setupMessageCallback();
  }

  /// Setup callback for receiving messages from JavaScript.
  void _setupMessageCallback() {
    // Create a global callback that can be called from JS
    globalContext.setProperty(
      'onXmtpMessage'.toJS,
      (JSAny messageData) {
        final map = _jsObjectToMap(messageData);
        _messageController.add(map);
      }.toJS,
    );
  }

  // ============================================================================
  // PLATFORM VERSION
  // ============================================================================

  @override
  Future<String?> getPlatformVersion() async {
    return 'Web';
  }

  // ============================================================================
  // CLIENT INITIALIZATION
  // ============================================================================

  @override
  Future<Uint8List> generatePrivateKey() async {
    try {
      final result = await _promiseToFuture(
        _clientManager.generatePrivateKey(),
      );
      final list = (result as JSArray).toDart;
      return Uint8List.fromList(list.cast<int>());
    } catch (e) {
      throw Exception('Failed to generate private key: $e');
    }
  }

  @override
  Future<String?> initializeClient(Uint8List privateKey, Uint8List dbKey, {String environment = 'production'}) async {
    try {
      final params = <String, dynamic>{
        'privateKey': privateKey.toList(),
        'dbKey': dbKey.toList(),
        'environment': environment,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.initializeClient(params),
      );

      return (result as JSString?)?.toDart;
    } catch (e) {
      throw Exception('Failed to initialize client: $e');
    }
  }

  @override
  Future<String?> getClientAddress() async {
    try {
      final result = await _promiseToFuture(
        _clientManager.getClientAddress(),
      );
      return (result as JSString?)?.toDart;
    } catch (e) {
      throw Exception('Failed to get client address: $e');
    }
  }

  @override
  Future<String?> getClientInboxId() async {
    try {
      final result = await _promiseToFuture(
        _clientManager.getClientInboxId(),
      );
      return (result as JSString?)?.toDart;
    } catch (e) {
      throw Exception('Failed to get client inbox ID: $e');
    }
  }

  // ============================================================================
  // MESSAGING
  // ============================================================================

  @override
  Future<String?> sendMessage(
    String recipientAddress,
    dynamic message,
    String authorityId,
    String typeId,
    int versionMajor,
  ) async {
    try {
      final params = <String, dynamic>{
        'recipientAddress': recipientAddress,
        'message': message,
        'authorityId': authorityId,
        'typeId': typeId,
        'versionMajor': versionMajor,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.sendMessage(params),
      );

      return (result as JSString?)?.toDart;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  @override
  Future<String?> sendMessageByInboxId(
    String recipientInboxId,
    dynamic message,
    String authorityId,
    String typeId,
    int versionMajor,
  ) async {
    try {
      final params = <String, dynamic>{
        'recipientInboxId': recipientInboxId,
        'message': message,
        'authorityId': authorityId,
        'typeId': typeId,
        'versionMajor': versionMajor,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.sendMessageByInboxId(params),
      );

      return (result as JSString?)?.toDart;
    } catch (e) {
      throw Exception('Failed to send message by inbox ID: $e');
    }
  }

  @override
  Future<String?> sendGroupMessage(
    String topic,
    dynamic message,
    String authorityId,
    String typeId,
    int versionMajor,
  ) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'message': message,
        'authorityId': authorityId,
        'typeId': typeId,
        'versionMajor': versionMajor,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.sendGroupMessage(params),
      );

      return (result as JSString?)?.toDart;
    } catch (e) {
      throw Exception('Failed to send group message: $e');
    }
  }

  // ============================================================================
  // MESSAGE STREAMING
  // ============================================================================

  @override
  Stream<Map<String, dynamic>> subscribeToAllMessages() {
    // Start subscription in JavaScript
    final callback = (JSAny messageData) {
      final map = _jsObjectToMap(messageData);
      _messageController.add(map);
    }.toJS;

    _clientManager.subscribeToAllMessages(callback);

    return _messageController.stream;
  }

  // ============================================================================
  // MESSAGE RETRIEVAL
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> getMessagesAfterDate(
    String peerAddress,
    DateTime fromDate,
  ) async {
    try {
      final params = <String, dynamic>{
        'peerAddress': peerAddress,
        'fromDate': fromDate.millisecondsSinceEpoch,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.getMessagesAfterDate(params),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to get messages after date: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesAfterDateByTopic(
    String topic,
    DateTime fromDate,
  ) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'fromDate': fromDate.millisecondsSinceEpoch,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.getMessagesAfterDateByTopic(params),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to get messages after date by topic: $e');
    }
  }

  // ============================================================================
  // CONVERSATION MANAGEMENT
  // ============================================================================

  @override
  Future<bool> acceptConversation(String topic) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.acceptConversation(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to accept conversation: $e');
    }
  }

  @override
  Future<bool> denyConversation(String topic) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.denyConversation(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to deny conversation: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listDms({String? consentState}) async {
    try {
      final params = <String, dynamic>{};
      if (consentState != null) {
        params['consentState'] = consentState;
      }

      final result = await _promiseToFuture(
        _clientManager.listDms(params.jsify() as JSObject),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to list DMs: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listGroups({String? consentState}) async {
    try {
      final params = <String, dynamic>{};
      if (consentState != null) {
        params['consentState'] = consentState;
      }

      final result = await _promiseToFuture(
        _clientManager.listGroups(params.jsify() as JSObject),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to list groups: $e');
    }
  }

  @override
  Future<bool> canMessage(String address) async {
    try {
      final params = <String, dynamic>{
        'address': address,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.canMessage(params),
      );

      return (result as JSBoolean).toDart;
    } catch (e) {
      throw Exception('Failed to check if can message: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> findOrCreateDMWithInboxId(String inboxId) async {
    try {
      final params = <String, dynamic>{
        'inboxId': inboxId,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.findOrCreateDMWithInboxId(params),
      );

      return _jsObjectToMap(result);
    } catch (e) {
      throw Exception('Failed to find or create DM: $e');
    }
  }

  @override
  Future<String> inboxIdFromAddress(String address) async {
    try {
      final params = <String, dynamic>{
        'address': address,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.inboxIdFromAddress(params),
      );

      return (result as JSString).toDart;
    } catch (e) {
      throw Exception('Failed to get inbox ID from address: $e');
    }
  }

  @override
  Future<String?> conversationTopicFromAddress(String peerAddress) async {
    try {
      final params = <String, dynamic>{
        'peerAddress': peerAddress,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.conversationTopicFromAddress(params),
      );

      return (result as JSString?)?.toDart;
    } catch (e) {
      throw Exception('Failed to get conversation topic: $e');
    }
  }

  // ============================================================================
  // GROUP OPERATIONS
  // ============================================================================

  @override
  Future<Map<String, dynamic>> newGroup(
    List<String> inboxIds,
    Map<String, String> options,
  ) async {
    try {
      final params = <String, dynamic>{
        'inboxIds': inboxIds,
        'options': options,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.newGroup(params),
      );

      return _jsObjectToMap(result);
    } catch (e) {
      throw Exception('Failed to create new group: $e');
    }
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupMembers(String topic) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.listGroupMembers(params),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to list group members: $e');
    }
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupAdmins(String topic) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.listGroupAdmins(params),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to list group admins: $e');
    }
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupSuperAdmins(String topic) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.listGroupSuperAdmins(params),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to list group super admins: $e');
    }
  }

  @override
  Future<bool> addGroupMembers(String topic, List<String> inboxIds) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'inboxIds': inboxIds,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.addGroupMembers(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to add group members: $e');
    }
  }

  @override
  Future<bool> removeGroupMembers(String topic, List<String> inboxIds) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'inboxIds': inboxIds,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.removeGroupMembers(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to remove group members: $e');
    }
  }

  @override
  Future<bool> addGroupAdmin(String topic, String inboxId) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'inboxId': inboxId,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.addGroupAdmin(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to add group admin: $e');
    }
  }

  @override
  Future<bool> removeGroupAdmin(String topic, String inboxId) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'inboxId': inboxId,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.removeGroupAdmin(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to remove group admin: $e');
    }
  }

  @override
  Future<bool> addGroupSuperAdmin(String topic, String inboxId) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'inboxId': inboxId,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.addGroupSuperAdmin(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to add group super admin: $e');
    }
  }

  @override
  Future<bool> removeGroupSuperAdmin(String topic, String inboxId) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'inboxId': inboxId,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.removeGroupSuperAdmin(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to remove group super admin: $e');
    }
  }

  @override
  Future<bool> updateGroup(String topic, Map<String, String> updates) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'updates': updates,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.updateGroup(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getGroupMemberRole(
    String topic,
    String inboxId,
  ) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'inboxId': inboxId,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.getGroupMemberRole(params),
      );

      return _jsObjectToMap(result);
    } catch (e) {
      throw Exception('Failed to get group member role: $e');
    }
  }

  // ============================================================================
  // ATTACHMENTS
  // ============================================================================

  @override
  Future<Map<String, dynamic>> loadRemoteAttachment(
    Map<String, dynamic> params,
  ) async {
    try {
      final jsParams = params.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.loadRemoteAttachment(jsParams),
      );

      return _jsObjectToMap(result);
    } catch (e) {
      throw Exception('Failed to load remote attachment: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> inboxStatesForInboxIds(
    List<String> inboxIds, {
    bool refreshFromNetwork = true,
  }) async {
    try {
      final params = <String, dynamic>{
        'inboxIds': inboxIds,
        'refreshFromNetwork': refreshFromNetwork,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.inboxStatesForInboxIds(params),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to get inbox states: $e');
    }
  }

  // ============================================================================
  // CONSENT MANAGEMENT
  // ============================================================================

  /// Get consent state for a conversation by topic
  @override
  Future<String> getConversationConsentState(String topic) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.getConversationConsentState(params),
      );

      return (result as JSString).toDart;
    } catch (e) {
      throw Exception('Failed to get conversation consent state: $e');
    }
  }

  /// Set consent state for a conversation by topic
  @override
  Future<bool> setConversationConsentState(String topic, String state) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
        'state': state,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.setConversationConsentState(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to set conversation consent state: $e');
    }
  }

  /// Get consent state for an inbox by inbox ID
  @override
  Future<String> getInboxConsentState(String inboxId) async {
    try {
      final params = <String, dynamic>{
        'inboxId': inboxId,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.getInboxConsentState(params),
      );

      return (result as JSString).toDart;
    } catch (e) {
      throw Exception('Failed to get inbox consent state: $e');
    }
  }

  /// Set consent state for an inbox by inbox ID
  @override
  Future<bool> setInboxConsentState(String inboxId, String state) async {
    try {
      final params = <String, dynamic>{
        'inboxId': inboxId,
        'state': state,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.setInboxConsentState(params),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to set inbox consent state: $e');
    }
  }

  /// Sync consent preferences from network
  @override
  Future<bool> syncConsentPreferences() async {
    try {
      await _promiseToFuture(
        _clientManager.syncConsentPreferences(),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to sync consent preferences: $e');
    }
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Send a sync request to trigger history transfer from other installations.
  /// This is the manual trigger for XMTP history sync across devices.
  @override
  Future<bool> sendSyncRequest() async {
    try {
      await _promiseToFuture(
        _clientManager.sendSyncRequest(),
      );

      return true;
    } catch (e) {
      throw Exception('Failed to send sync request: $e');
    }
  }

  /// Sync all conversations from network
  @override
  Future<Map<String, int>> syncAll({List<String> consentStates = const ['allowed']}) async {
    try {
      final params = <String, dynamic>{
        'consentStates': consentStates,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.syncAll(params),
      );

      final map = _jsObjectToMap(result);
      return {'numGroupsSynced': (map['numGroupsSynced'] as num?)?.toInt() ?? 0};
    } catch (e) {
      throw Exception('Failed to sync all: $e');
    }
  }

  /// Sync a single conversation by topic
  @override
  Future<void> syncConversation(String topic) async {
    try {
      final params = <String, dynamic>{
        'topic': topic,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.syncConversation(params),
      );
    } catch (e) {
      throw Exception('Failed to sync conversation: $e');
    }
  }

  // ============================================================================
  // ADDITIONAL CONVERSATION METHODS
  // ============================================================================

  @override
  Future<List<Map<String, dynamic>>> listConversations() async {
    try {
      final result = await _promiseToFuture(
        _clientManager.listConversations(),
      );

      return _jsArrayToListOfMaps(result as JSArray);
    } catch (e) {
      throw Exception('Failed to list conversations: $e');
    }
  }

  /// Check if can message by inbox ID
  @override
  Future<bool> canMessageByInboxId(String inboxId) async {
    try {
      final params = <String, dynamic>{
        'inboxId': inboxId,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.canMessageByInboxId(params),
      );

      return (result as JSBoolean).toDart;
    } catch (e) {
      throw Exception('Failed to check if can message by inbox ID: $e');
    }
  }

  // ============================================================================
  // INBOX MANAGEMENT
  // ============================================================================

  /// Get current installation ID
  @override
  Future<String> getInstallationId() async {
    try {
      final result = await _promiseToFuture(
        _clientManager.getInstallationId(),
      );

      return (result as JSString).toDart;
    } catch (e) {
      throw Exception('Failed to get installation ID: $e');
    }
  }

  /// Get inbox state for current client
  @override
  Future<Map<String, dynamic>> inboxState({bool refreshFromNetwork = false}) async {
    try {
      final params = <String, dynamic>{
        'refreshFromNetwork': refreshFromNetwork,
      }.jsify() as JSObject;

      final result = await _promiseToFuture(
        _clientManager.inboxState(params),
      );

      return _jsObjectToMap(result);
    } catch (e) {
      throw Exception('Failed to get inbox state: $e');
    }
  }

  /// Revoke specific installations
  @override
  Future<void> revokeInstallations(Uint8List signerPrivateKey, List<String> installationIds) async {
    try {
      final params = <String, dynamic>{
        'signerPrivateKey': signerPrivateKey.toList(),
        'installationIds': installationIds,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.revokeInstallations(params),
      );
    } catch (e) {
      throw Exception('Failed to revoke installations: $e');
    }
  }

  /// Revoke all other installations
  @override
  Future<void> revokeAllOtherInstallations(Uint8List signerPrivateKey) async {
    try {
      final params = <String, dynamic>{
        'signerPrivateKey': signerPrivateKey.toList(),
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.revokeAllOtherInstallations(params),
      );
    } catch (e) {
      throw Exception('Failed to revoke all other installations: $e');
    }
  }

  /// Add a new account to the inbox
  @override
  Future<void> addAccount(Uint8List newAccountPrivateKey, {bool allowReassignInboxId = false}) async {
    try {
      final params = <String, dynamic>{
        'newAccountPrivateKey': newAccountPrivateKey.toList(),
        'allowReassignInboxId': allowReassignInboxId,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.addAccount(params),
      );
    } catch (e) {
      throw Exception('Failed to add account: $e');
    }
  }

  /// Remove an account from the inbox
  @override
  Future<void> removeAccount(Uint8List recoveryPrivateKey, String identifierToRemove) async {
    try {
      final params = <String, dynamic>{
        'recoveryPrivateKey': recoveryPrivateKey.toList(),
        'identifierToRemove': identifierToRemove,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.removeAccount(params),
      );
    } catch (e) {
      throw Exception('Failed to remove account: $e');
    }
  }

  /// Change recovery identifier
  @override
  Future<void> changeRecoveryIdentifier(Uint8List signerPrivateKey, String newRecoveryIdentifier) async {
    try {
      final params = <String, dynamic>{
        'signerPrivateKey': signerPrivateKey.toList(),
        'newRecoveryIdentifier': newRecoveryIdentifier,
      }.jsify() as JSObject;

      await _promiseToFuture(
        _clientManager.changeRecoveryIdentifier(params),
      );
    } catch (e) {
      throw Exception('Failed to change recovery identifier: $e');
    }
  }

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  /// Convert a JavaScript Promise to a Dart Future.
  Future<JSAny?> _promiseToFuture(JSPromise promise) {
    final completer = Completer<JSAny?>();

    promise.toDart.then(
      (JSAny? value) {
        completer.complete(value);
      },
      onError: (Object error) {
        completer.completeError(error.toString());
      },
    );

    return completer.future;
  }

  /// Convert a JavaScript object to a Dart Map.
  Map<String, dynamic> _jsObjectToMap(JSAny? jsObject) {
    if (jsObject == null) return {};

    final map = <String, dynamic>{};
    final object = jsObject as JSObject;

    // Get all keys using Object.keys() from JavaScript
    final keysArray = _objectKeys(object);
    final keys = keysArray.toDart;

    for (final key in keys) {
      final jsKey = key as JSString;
      final keyString = jsKey.toDart;
      final value = object.getProperty(keyString.toJS);

      map[keyString] = _jsValueToDart(value);
    }

    return map;
  }

  /// Call JavaScript's Object.keys() method
  JSArray _objectKeys(JSObject obj) {
    final objectConstructor = globalContext.getProperty('Object'.toJS) as JSObject;
    final keysFunction = objectConstructor.getProperty('keys'.toJS) as JSFunction;
    return keysFunction.callAsFunction(objectConstructor, obj) as JSArray;
  }

  /// Convert a JavaScript array to a Dart List of Maps.
  List<Map<String, dynamic>> _jsArrayToListOfMaps(JSArray jsArray) {
    final list = <Map<String, dynamic>>[];
    final dartList = jsArray.toDart;

    for (final item in dartList) {
      if (item is JSObject) {
        list.add(_jsObjectToMap(item));
      }
    }

    return list;
  }

  /// Convert JavaScript value to Dart type.
  dynamic _jsValueToDart(JSAny? value) {
    if (value == null) return null;

    // Try different JS types
    if (value.typeofEquals('string')) {
      return (value as JSString).toDart;
    }
    if (value.typeofEquals('number')) {
      return (value as JSNumber).toDartDouble;
    }
    if (value.typeofEquals('boolean')) {
      return (value as JSBoolean).toDart;
    }
    if (value is JSArray) {
      return value.toDart.map(_jsValueToDart).toList();
    }
    if (value is JSObject) {
      return _jsObjectToMap(value);
    }

    return value;
  }
}

// ============================================================================
// JAVASCRIPT INTEROP DEFINITIONS
// ============================================================================

/// JavaScript interop definition for the XMTP Client Manager.
extension type XMTPClientManager(JSObject _) implements JSObject {
  // Client initialization
  external JSPromise generatePrivateKey();
  external JSPromise initializeClient(JSObject params);
  external JSPromise getClientAddress();
  external JSPromise getClientInboxId();

  // Messaging
  external JSPromise sendMessage(JSObject params);
  external JSPromise sendMessageByInboxId(JSObject params);
  external JSPromise sendGroupMessage(JSObject params);
  external JSPromise subscribeToAllMessages(JSFunction callback);
  external JSPromise getMessagesAfterDate(JSObject params);
  external JSPromise getMessagesAfterDateByTopic(JSObject params);

  // Conversation management
  external JSPromise acceptConversation(JSObject params);
  external JSPromise denyConversation(JSObject params);
  external JSPromise listDms(JSObject params);
  external JSPromise listGroups(JSObject params);
  external JSPromise listConversations();
  external JSPromise canMessage(JSObject params);
  external JSPromise canMessageByInboxId(JSObject params);
  external JSPromise findOrCreateDMWithInboxId(JSObject params);
  external JSPromise inboxIdFromAddress(JSObject params);
  external JSPromise conversationTopicFromAddress(JSObject params);

  // Group operations
  external JSPromise newGroup(JSObject params);
  external JSPromise listGroupMembers(JSObject params);
  external JSPromise listGroupAdmins(JSObject params);
  external JSPromise listGroupSuperAdmins(JSObject params);
  external JSPromise addGroupMembers(JSObject params);
  external JSPromise removeGroupMembers(JSObject params);
  external JSPromise addGroupAdmin(JSObject params);
  external JSPromise removeGroupAdmin(JSObject params);
  external JSPromise addGroupSuperAdmin(JSObject params);
  external JSPromise removeGroupSuperAdmin(JSObject params);
  external JSPromise updateGroup(JSObject params);
  external JSPromise getGroupMemberRole(JSObject params);

  // Attachments
  external JSPromise loadRemoteAttachment(JSObject params);

  // Consent management
  external JSPromise getConversationConsentState(JSObject params);
  external JSPromise setConversationConsentState(JSObject params);
  external JSPromise getInboxConsentState(JSObject params);
  external JSPromise setInboxConsentState(JSObject params);
  external JSPromise syncConsentPreferences();

  // Sync operations
  external JSPromise sendSyncRequest();
  external JSPromise syncAll(JSObject params);
  external JSPromise syncConversation(JSObject params);

  // Inbox management
  external JSPromise getInstallationId();
  external JSPromise inboxState(JSObject params);
  external JSPromise inboxStatesForInboxIds(JSObject params);
  external JSPromise revokeInstallations(JSObject params);
  external JSPromise revokeAllOtherInstallations(JSObject params);
  external JSPromise addAccount(JSObject params);
  external JSPromise removeAccount(JSObject params);
  external JSPromise changeRecoveryIdentifier(JSObject params);
}

/// Global context for accessing window object properties.
@JS('window')
external JSObject get globalContext;
