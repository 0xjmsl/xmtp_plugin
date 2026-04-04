import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'xmtp_plugin_platform_interface.dart';

/// An implementation of [XmtpPluginPlatform] that uses method channels.
class MethodChannelXmtpPlugin extends XmtpPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('xmtp_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<Uint8List> generatePrivateKey() async {
    final Uint8List privateKeyBytes = await methodChannel.invokeMethod('generatePrivateKey');
    return privateKeyBytes;
  }

  @override
  Future<String?> initializeClient(Uint8List privateKey, Uint8List dbKey, {String environment = 'production'}) async {
    final address = await methodChannel.invokeMethod<String>(
      'initializeClient',
      {
        'privateKey': privateKey,
        'dbKey': dbKey,
        'environment': environment,
      },
    );
    return address;
  }

  @override
  Future<String?> getClientAddress() async {
    final address = await methodChannel.invokeMethod<String>('getClientAddress');
    return address;
  }

  @override
  Future<String?> getClientInboxId() async {
    final inboxId = await methodChannel.invokeMethod<String>('getClientInboxId');
    return inboxId;
  }

  @override
  Future<String?> sendMessage(String recipientAddress, dynamic message, String authorityId, String typeId, int versionMajor) async {
    if (message is! Map<String, dynamic>) {
      throw const FormatException('Message must be a Map with content and parameters');
    }

    final result = await methodChannel.invokeMethod<String>('sendMessage', {
      'recipientAddress': recipientAddress,
      'message': message,
      'authorityId': authorityId,
      'typeId': typeId,
      'versionMajor': versionMajor,
    });
    return result;
  }

  @override
  Future<String?> sendMessageByInboxId(String recipientInboxId, dynamic message, String authorityId, String typeId, int versionMajor) async {
    if (message is! Map<String, dynamic>) {
      throw const FormatException('Message must be a Map with content and parameters');
    }

    final result = await methodChannel.invokeMethod<String>('sendMessageByInboxId', {
      'recipientInboxId': recipientInboxId,
      'message': message,
      'authorityId': authorityId,
      'typeId': typeId,
      'versionMajor': versionMajor,
    });
    return result;
  }

  @override
  Future<String?> sendGroupMessage(String topic, dynamic message, String authorityId, String typeId, int versionMajor) async {
    if (message is! Map<String, dynamic>) {
      throw const FormatException('Message must be a Map with content and parameters');
    }

    final result = await methodChannel.invokeMethod<String>('sendGroupMessage', {
      'topic': topic,
      'message': message,
      'authorityId': authorityId,
      'typeId': typeId,
      'versionMajor': versionMajor,
    });
    return result;
  }

  @override
  Stream<Map<String, dynamic>> subscribeToAllMessages() {
    final StreamController<Map<String, dynamic>> controller = StreamController<Map<String, dynamic>>();

    methodChannel.invokeMethod('subscribeToAllMessages');

    methodChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onMessageReceived') {
        final Map<String, dynamic> message = Map<String, dynamic>.from(call.arguments);
        print('Message Received: $message');
        controller.add(message);
      }
    });

    return controller.stream;
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesAfterDate(String peerAddress, DateTime fromDate) async {
    final List<dynamic> result = await methodChannel.invokeMethod('getMessagesAfterDate', {
      'peerAddress': peerAddress,
      'fromDate': fromDate.millisecondsSinceEpoch,
    });
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesAfterDateByTopic(String topic, DateTime fromDate) async {
    final List<dynamic> result = await methodChannel.invokeMethod('getMessagesAfterDateByTopic', {
      'topic': topic,
      'fromDate': fromDate.millisecondsSinceEpoch,
    });
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>> loadRemoteAttachment(Map<String, dynamic> params) async {
    try {
      final result = await methodChannel.invokeMethod('loadRemoteAttachment', params);

      if (result == null) {
        throw Exception('Failed to load remote attachment: received null result');
      }

      final Map<String, dynamic> attachmentMap = Map<String, dynamic>.from(result);

      if (!attachmentMap.containsKey('filename') || !attachmentMap.containsKey('mimeType') || !attachmentMap.containsKey('data')) {
        throw Exception('Invalid attachment format received from platform');
      }

      if (attachmentMap['data'] is List) {
        attachmentMap['data'] = Uint8List.fromList(List<int>.from(attachmentMap['data']));
      }

      return attachmentMap;
    } catch (e) {
      throw Exception('Failed to load remote attachment: $e');
    }
  }

  @override
  Future<bool> acceptConversation(String topic) async {
    final result = await methodChannel.invokeMethod<bool>('acceptConversation', {
      'topic': topic,
    });
    return result ?? false;
  }

  @override
  Future<bool> denyConversation(String topic) async {
    final result = await methodChannel.invokeMethod<bool>('denyConversation', {
      'topic': topic,
    });
    return result ?? false;
  }

  @override
  Future<List<Map<String, dynamic>>> listConversations() async {
    final List<dynamic> result = await methodChannel.invokeMethod('listConversations');
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listDms({String? consentState}) async {
    final List<dynamic> result = await methodChannel.invokeMethod('listDms', {
      'consentState': consentState,
    });
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> listGroups({String? consentState}) async {
    final List<dynamic> result = await methodChannel.invokeMethod('listGroups', {
      'consentState': consentState,
    });
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<bool> canMessage(String address) async {
    final result = await methodChannel.invokeMethod<bool>('canMessageByAddress', {
      'address': address,
    });
    return result ?? false;
  }

  @override
  Future<bool> canMessageByInboxId(String inboxId) async {
    final result = await methodChannel.invokeMethod<bool>('canMessageByInboxId', {
      'inboxId': inboxId,
    });
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> findOrCreateDMWithInboxId(String inboxId) async {
    final result = await methodChannel.invokeMethod('findOrCreateDMWithInboxId', {
      'inboxId': inboxId,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<String> inboxIdFromAddress(String address) async {
    final result = await methodChannel.invokeMethod<String>('inboxIdFromAddress', {
      'address': address,
    });
    return result ?? "";
  }

  @override
  Future<String?> conversationTopicFromAddress(String peerAddress) async {
    final String? topic = await methodChannel.invokeMethod<String>(
      'conversationTopicFromAddress',
      {'peerAddress': peerAddress},
    );
    return topic;
  }

  @override
  Future<Map<String, dynamic>> newGroup(List<String> inboxIds, Map<String, String> options) async {
    final result = await methodChannel.invokeMethod('newGroup', {
      'inboxIds': inboxIds,
      'options': options,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupMembers(String topic) async {
    final result = await methodChannel.invokeMethod('listGroupMembers', {
      'topic': topic,
    });

    print('listGroupMembers result: $result');
    final List<dynamic> resultList = result as List<dynamic>;

    return resultList.map((item) {
      final map = item as Map<Object?, Object?>;
      return map.map((key, value) => MapEntry(key.toString(), value as dynamic));
    }).toList();
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupAdmins(String topic) async {
    final result = await methodChannel.invokeMethod('listGroupAdmins', {
      'topic': topic,
    });
    return List<Map<dynamic, dynamic>>.from(result);
  }

  @override
  Future<List<Map<dynamic, dynamic>>> listGroupSuperAdmins(String topic) async {
    final result = await methodChannel.invokeMethod('listGroupSuperAdmins', {
      'topic': topic,
    });
    return List<Map<dynamic, dynamic>>.from(result);
  }

  @override
  Future<bool> addGroupMembers(String topic, List<String> inboxIds) async {
    final result = await methodChannel.invokeMethod<bool>('addGroupMembers', {
      'topic': topic,
      'inboxIds': inboxIds,
    });
    return result ?? false;
  }

  @override
  Future<bool> removeGroupMembers(String topic, List<String> inboxIds) async {
    final result = await methodChannel.invokeMethod<bool>('removeGroupMembers', {
      'topic': topic,
      'inboxIds': inboxIds,
    });
    return result ?? false;
  }

  @override
  Future<bool> addGroupAdmin(String topic, String inboxId) async {
    final result = await methodChannel.invokeMethod<bool>('addGroupAdmin', {
      'topic': topic,
      'inboxId': inboxId,
    });
    return result ?? false;
  }

  @override
  Future<bool> removeGroupAdmin(String topic, String inboxId) async {
    final result = await methodChannel.invokeMethod<bool>('removeGroupAdmin', {
      'topic': topic,
      'inboxId': inboxId,
    });
    return result ?? false;
  }

  @override
  Future<bool> addGroupSuperAdmin(String topic, String inboxId) async {
    final result = await methodChannel.invokeMethod<bool>('addGroupSuperAdmin', {
      'topic': topic,
      'inboxId': inboxId,
    });
    return result ?? false;
  }

  @override
  Future<bool> removeGroupSuperAdmin(String topic, String inboxId) async {
    final result = await methodChannel.invokeMethod<bool>('removeGroupSuperAdmin', {
      'topic': topic,
      'inboxId': inboxId,
    });
    return result ?? false;
  }

  @override
  Future<bool> updateGroup(String topic, Map<String, String> updates) async {
    final result = await methodChannel.invokeMethod<bool>('updateGroup', {
      'topic': topic,
      'updates': updates,
    });
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> getGroupMemberRole(String topic, String inboxId) async {
    final result = await methodChannel.invokeMethod('getGroupMemberRole', {
      'topic': topic,
      'inboxId': inboxId,
    });
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<List<Map<String, dynamic>>> inboxStatesForInboxIds(List<String> inboxIds, {bool refreshFromNetwork = true}) async {
    final List<dynamic> result = await methodChannel.invokeMethod('inboxStatesForInboxIds', {
      'inboxIds': inboxIds,
      'refreshFromNetwork': refreshFromNetwork,
    });
    return List<Map<String, dynamic>>.from(result.map((e) => Map<String, dynamic>.from(e)));
  }

  // ============================================================================
  // CONSENT MANAGEMENT
  // ============================================================================

  @override
  Future<String> getConversationConsentState(String topic) async {
    final String result = await methodChannel.invokeMethod('getConversationConsentState', {
      'topic': topic,
    });
    return result;
  }

  @override
  Future<bool> setConversationConsentState(String topic, String state) async {
    final bool result = await methodChannel.invokeMethod('setConversationConsentState', {
      'topic': topic,
      'state': state,
    });
    return result;
  }

  @override
  Future<String> getInboxConsentState(String inboxId) async {
    final String result = await methodChannel.invokeMethod('getInboxConsentState', {
      'inboxId': inboxId,
    });
    return result;
  }

  @override
  Future<bool> setInboxConsentState(String inboxId, String state) async {
    final bool result = await methodChannel.invokeMethod('setInboxConsentState', {
      'inboxId': inboxId,
      'state': state,
    });
    return result;
  }

  @override
  Future<bool> syncConsentPreferences() async {
    final bool result = await methodChannel.invokeMethod('syncConsentPreferences');
    return result;
  }

  // ============================================================================
  // SYNC & INBOX
  // ============================================================================

  @override
  Future<bool> sendSyncRequest() async {
    final bool result = await methodChannel.invokeMethod('sendSyncRequest');
    return result;
  }

  @override
  Future<Map<String, int>> syncAll({List<String> consentStates = const ['allowed']}) async {
    final result = await methodChannel.invokeMethod('syncAll', {
      'consentStates': consentStates,
    });
    if (result == null) {
      return {'numGroupsSynced': 0};
    }
    return Map<String, int>.from(result.map((key, value) => MapEntry(key, value as int)));
  }

  @override
  Future<void> syncConversation(String topic) async {
    await methodChannel.invokeMethod('syncConversation', {
      'topic': topic,
    });
  }

  @override
  Future<String> getInstallationId() async {
    final String result = await methodChannel.invokeMethod('getInstallationId');
    return result;
  }

  @override
  Future<Map<String, dynamic>> inboxState({bool refreshFromNetwork = false}) async {
    final result = await methodChannel.invokeMethod('inboxState', {
      'refreshFromNetwork': refreshFromNetwork,
    });
    return _deepConvertMap(result);
  }

  @override
  Future<void> revokeInstallations(Uint8List signerPrivateKey, List<String> installationIds) async {
    await methodChannel.invokeMethod('revokeInstallations', {
      'signerPrivateKey': signerPrivateKey,
      'installationIds': installationIds,
    });
  }

  @override
  Future<void> revokeAllOtherInstallations(Uint8List signerPrivateKey) async {
    await methodChannel.invokeMethod('revokeAllOtherInstallations', {
      'signerPrivateKey': signerPrivateKey,
    });
  }

  @override
  Future<void> addAccount(Uint8List newAccountPrivateKey, {bool allowReassignInboxId = false}) async {
    await methodChannel.invokeMethod('addAccount', {
      'newAccountPrivateKey': newAccountPrivateKey,
      'allowReassignInboxId': allowReassignInboxId,
    });
  }

  @override
  Future<void> removeAccount(Uint8List recoveryPrivateKey, String identifierToRemove) async {
    await methodChannel.invokeMethod('removeAccount', {
      'recoveryPrivateKey': recoveryPrivateKey,
      'identifierToRemove': identifierToRemove,
    });
  }

  // ============================================================================
  // STATIC OPERATIONS
  // ============================================================================

  @override
  Future<void> staticRevokeInstallations(Uint8List signerPrivateKey, String inboxId, List<String> installationIds) async {
    await methodChannel.invokeMethod('staticRevokeInstallations', {
      'signerPrivateKey': signerPrivateKey,
      'inboxId': inboxId,
      'installationIds': installationIds,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> staticInboxStatesForInboxIds(List<String> inboxIds) async {
    final List<dynamic> result = await methodChannel.invokeMethod('staticInboxStatesForInboxIds', {
      'inboxIds': inboxIds,
    });
    return List<Map<String, dynamic>>.from(result.map((e) => Map<String, dynamic>.from(e)));
  }

  @override
  Future<void> changeRecoveryIdentifier(Uint8List signerPrivateKey, String newRecoveryIdentifier) async {
    await methodChannel.invokeMethod('changeRecoveryIdentifier', {
      'signerPrivateKey': signerPrivateKey,
      'newRecoveryIdentifier': newRecoveryIdentifier,
    });
  }

  /// Helper to deeply convert method channel maps to Map<String, dynamic>
  Map<String, dynamic> _deepConvertMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map((e) => MapEntry(
          e.key.toString(),
          _deepConvertValue(e.value),
        )),
      );
    }
    return <String, dynamic>{};
  }

  dynamic _deepConvertValue(dynamic value) {
    if (value is Map) {
      return _deepConvertMap(value);
    } else if (value is List) {
      return value.map((e) => _deepConvertValue(e)).toList();
    }
    return value;
  }
}
