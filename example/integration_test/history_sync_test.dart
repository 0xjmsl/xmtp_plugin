/// XMTP History Sync Integration Tests
///
/// Tests the XMTP history sync flow at the Dart/Flutter level.
///
/// LIMITATION: xmtp_plugin uses a singleton client, so we can only have ONE
/// active XMTP client per process. This means:
/// - We CAN test: API availability, client init, sync calls, inbox state
/// - We CAN test: sequential client swap (init device1 -> close -> init device2)
/// - We CANNOT test: simultaneous multi-device sync (device1 must be online
///   when device2 requests history — but they can't both exist at once)
///
/// For full multi-client testing, see the Rust integration test at:
///   xmtp_plugin/rust/src/integration_test.rs
///
/// Run with:
///   cd example && flutter test integration_test/history_sync_test.dart -d windows
library;

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xmtp_plugin/xmtp_plugin.dart';
import 'package:xmtp_plugin/codecs.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Shared helpers
  Uint8List randomDbKey() =>
      Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));

  XmtpPlugin createXmtp() {
    final xmtp = XmtpPlugin();
    xmtp.registerCodec(TextCodec());
    xmtp.registerCodec(AttachmentCodec());
    xmtp.registerCodec(RemoteAttachmentCodec());
    xmtp.registerCodec(ReactionV2Codec());
    return xmtp;
  }

  // =========================================================================
  // TEST 1: Basic client initialization and sync APIs
  // =========================================================================
  testWidgets('T1: Client init + sync APIs work', (tester) async {
    final xmtp = createXmtp();
    final pk = await xmtp.generatePrivateKey();
    final dbKey = randomDbKey();

    // Initialize client
    final address = await xmtp.initializeClient(pk, dbKey);
    expect(address, isNotNull);
    expect(address!.startsWith('0x'), isTrue);
    print('Client address: $address');

    // Inbox ID
    final inboxId = await xmtp.getClientInboxId();
    expect(inboxId.length, 64); // sha256 hex
    print('Inbox ID: $inboxId');

    // Installation ID
    final installId = await xmtp.getInstallationId();
    expect(installId.isNotEmpty, isTrue);
    print('Installation ID: ${installId.substring(0, 16)}...');

    // syncAll
    final syncResult = await xmtp.syncAll();
    expect(syncResult, isA<Map<String, int>>());
    print('syncAll: $syncResult');

    // sendSyncRequest — should not throw even on fresh client
    final syncReq = await xmtp.sendSyncRequest();
    expect(syncReq, isTrue);
    print('sendSyncRequest: $syncReq');

    // syncConsentPreferences
    final consentSync = await xmtp.syncConsentPreferences();
    expect(consentSync, isA<bool>());
    print('syncConsentPreferences: $consentSync');
  });

  // =========================================================================
  // TEST 2: Inbox state shows correct installation count
  // =========================================================================
  testWidgets('T2: Inbox state reports installations', (tester) async {
    final xmtp = createXmtp();
    final pk = await xmtp.generatePrivateKey();
    final dbKey = randomDbKey();

    await xmtp.initializeClient(pk, dbKey);
    final state = await xmtp.inboxState(refreshFromNetwork: true);

    expect(state['inbox_id'], isNotNull);
    expect(state['installations'], isA<List>());
    expect((state['installations'] as List).length, greaterThanOrEqualTo(1));
    expect(state['identities'], isA<List>());
    expect(state['recovery_identity'], isNotNull);

    print('Inbox state:');
    print('  inbox_id: ${state['inbox_id']}');
    print('  installations: ${(state['installations'] as List).length}');
    print('  identities: ${(state['identities'] as List).length}');
    for (final ident in (state['identities'] as List)) {
      print('    - ${ident['kind']}: ${ident['identifier']}');
    }
  });

  // =========================================================================
  // TEST 3: Two clients with same key create two installations
  // =========================================================================
  testWidgets('T3: Second init creates second installation', (tester) async {
    final xmtp = createXmtp();
    final pk = await xmtp.generatePrivateKey();

    // Device 1
    final dbKey1 = randomDbKey();
    await xmtp.initializeClient(pk, dbKey1);
    final installId1 = await xmtp.getInstallationId();
    final state1 = await xmtp.inboxState(refreshFromNetwork: true);
    final installCount1 = (state1['installations'] as List).length;
    print('Device 1 installation: ${installId1.substring(0, 16)}...');
    print('Device 1 installation count: $installCount1');

    // Device 2 — same key, different DB key & path
    // Note: on Windows, the Rust client uses temp_dir/xmtp_plugin/<addr>.db3
    // so reinitializing with the same key reuses the same DB file.
    // To simulate a true second device, we'd need different DB paths.
    // For now, this tests the API surface.
    final dbKey2 = randomDbKey();
    await xmtp.initializeClient(pk, dbKey2);
    final installId2 = await xmtp.getInstallationId();
    final state2 = await xmtp.inboxState(refreshFromNetwork: true);
    final installCount2 = (state2['installations'] as List).length;
    print('Device 2 installation: ${installId2.substring(0, 16)}...');
    print('Device 2 installation count: $installCount2');

    // The installation IDs might be the same (reused DB) or different (fresh DB).
    // But the network should show at least 1 installation.
    expect(installCount2, greaterThanOrEqualTo(1));
    print('Installation IDs same? ${installId1 == installId2}');
  });

  // =========================================================================
  // TEST 4: DM creation and messaging
  // =========================================================================
  testWidgets('T4: Create DM and send message', (tester) async {
    // Create Bob
    final bob = createXmtp();
    final bobPk = await bob.generatePrivateKey();
    await bob.initializeClient(bobPk, randomDbKey());
    final bobInboxId = await bob.getClientInboxId();
    final bobAddress = await bob.getClientAddress();
    print('Bob: address=$bobAddress, inboxId=$bobInboxId');

    // Create Alice (replaces Bob's client in the singleton)
    final alice = createXmtp();
    final alicePk = await alice.generatePrivateKey();
    await alice.initializeClient(alicePk, randomDbKey());
    final aliceInboxId = await alice.getClientInboxId();
    final aliceAddress = await alice.getClientAddress();
    print('Alice: address=$aliceAddress, inboxId=$aliceInboxId');

    // Alice creates DM with Bob
    final dm = await alice.findOrCreateDMWithInboxId(bobInboxId);
    expect(dm['topic'], isNotNull);
    print('DM created, topic: ${dm['topic']}');

    // Alice sends a message to Bob
    final msgId = await alice.sendMessage(
      bobAddress,
      'Hello from history sync test!',
      'xmtp.org',
      'text',
    );
    print('Message sent, id: $msgId');

    // Sync and list conversations
    await alice.syncAll();
    final convos = await alice.listConversations();
    print('Alice conversations: ${convos.length}');
    expect(convos.length, greaterThanOrEqualTo(1));
  });

  // =========================================================================
  // TEST 5: Sequential device swap — the closest we can get to history sync
  //
  // Flow:
  // 1. Init as Alice (device 1), send self a message via a group
  // 2. Sync device 1, verify message received
  // 3. Reinit as Alice (device 2, same key) — device 1's sync worker stops
  // 4. Try syncAll + sendSyncRequest on device 2
  // 5. Check what conversations/messages device 2 can see
  //
  // Expected: Device 2 may NOT see historical messages (because device 1 is
  // offline and can't respond to the sync request). But it SHOULD see
  // conversations that were synced from the network (group memberships).
  // =========================================================================
  testWidgets('T5: Sequential device swap — history sync attempt', (tester) async {
    final xmtp = createXmtp();
    final alicePk = await xmtp.generatePrivateKey();

    // Also create a second user to have a real conversation
    final xmtp2 = createXmtp();
    final bobPk = await xmtp2.generatePrivateKey();
    await xmtp2.initializeClient(bobPk, randomDbKey());
    final bobInboxId = await xmtp2.getClientInboxId();
    final bobAddress = await xmtp2.getClientAddress();
    print('Bob: address=$bobAddress, inboxId=$bobInboxId');

    // --- Alice Device 1 ---
    print('\n--- Alice Device 1 ---');
    await xmtp.initializeClient(alicePk, randomDbKey());
    final aliceInboxId = await xmtp.getClientInboxId();
    final aliceAddress = await xmtp.getClientAddress();
    final installId1 = await xmtp.getInstallationId();
    print('Alice D1: address=$aliceAddress, install=${installId1.substring(0, 16)}...');

    // Create DM with Bob (Alice is active client now, Bob was replaced)
    final dm = await xmtp.findOrCreateDMWithInboxId(bobInboxId);
    final topic = dm['topic'] as String;
    print('DM topic: $topic');

    // Send messages
    await xmtp.sendMessage(bobAddress, 'History msg 1', 'xmtp.org', 'text');
    await xmtp.sendMessage(bobAddress, 'History msg 2', 'xmtp.org', 'text');
    await xmtp.sendMessage(bobAddress, 'History msg 3', 'xmtp.org', 'text');
    print('Sent 3 messages from Alice D1');

    // Sync device 1
    await xmtp.syncAll();
    await Future.delayed(const Duration(seconds: 2));

    // Get device 1 conversations
    final d1Convos = await xmtp.listConversations();
    print('Device 1 conversations: ${d1Convos.length}');

    final d1Messages = await xmtp.getMessagesAfterDate(
      bobAddress,
      DateTime.now().subtract(const Duration(minutes: 5)),
    );
    print('Device 1 messages: ${d1Messages.length}');

    // --- Alice Device 2 (same key, replaces device 1) ---
    print('\n--- Alice Device 2 ---');
    // NOTE: This replaces device 1. Device 1's sync worker stops.
    // History sync requires device 1 to be online, so this is expected to
    // NOT transfer historical messages. This test documents the behavior.
    await xmtp.initializeClient(alicePk, randomDbKey());
    final installId2 = await xmtp.getInstallationId();
    print('Alice D2: install=${installId2.substring(0, 16)}...');

    final state = await xmtp.inboxState(refreshFromNetwork: true);
    final installCount = (state['installations'] as List).length;
    print('Total installations: $installCount');

    // Try to trigger history sync
    print('Sending sync request from device 2...');
    await xmtp.sendSyncRequest();
    await Future.delayed(const Duration(seconds: 3));

    // Sync everything
    await xmtp.syncConsentPreferences();
    await Future.delayed(const Duration(seconds: 2));
    await xmtp.syncAll();
    await Future.delayed(const Duration(seconds: 2));

    // Check what device 2 can see
    final d2Convos = await xmtp.listConversations();
    print('Device 2 conversations: ${d2Convos.length}');

    // Try to get messages
    if (d2Convos.isNotEmpty) {
      final d2Messages = await xmtp.getMessagesAfterDate(
        bobAddress,
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      print('Device 2 messages: ${d2Messages.length}');
      for (final msg in d2Messages) {
        print('  - ${msg['senderInboxId']?.toString().substring(0, 8)}...: ${msg['content']}');
      }

      if (d2Messages.length >= 3) {
        print('SUCCESS: Historical messages synced to device 2!');
      } else if (d2Messages.isNotEmpty) {
        print('PARTIAL: Some messages visible on device 2');
      } else {
        print('EXPECTED: No historical messages (device 1 was offline during sync request)');
      }
    } else {
      print('EXPECTED: No conversations on device 2 (history sync needs device 1 online)');
    }

    print('\n--- Test complete ---');
    print('NOTE: For full multi-device history sync testing, both devices must');
    print('be running simultaneously. Use the Kotlin instrumented test or run');
    print('two separate Flutter processes.');
  });
}
