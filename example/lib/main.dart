import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xmtp_plugin/xmtp_plugin.dart';
import 'package:xmtp_plugin/codecs.dart';

/// Minimal harness for testing XMTP history sync.
/// Run integration tests with:
///   flutter test integration_test/history_sync_test.dart -d windows
void main() {
  runApp(const HistorySyncTestApp());
}

class HistorySyncTestApp extends StatefulWidget {
  const HistorySyncTestApp({super.key});

  @override
  State<HistorySyncTestApp> createState() => _HistorySyncTestAppState();
}

class _HistorySyncTestAppState extends State<HistorySyncTestApp> {
  final _log = <String>[];
  bool _running = false;

  void _addLog(String msg) {
    setState(() => _log.add('[${DateTime.now().toString().substring(11, 19)}] $msg'));
  }

  Future<void> _runBasicTest() async {
    if (_running) return;
    setState(() {
      _running = true;
      _log.clear();
    });

    try {
      final xmtp = XmtpPlugin();
      xmtp.registerCodec(TextCodec());
      xmtp.registerCodec(AttachmentCodec());
      xmtp.registerCodec(RemoteAttachmentCodec());
      xmtp.registerCodec(ReactionV2Codec());

      _addLog('Generating private key...');
      final pk = await xmtp.generatePrivateKey();
      _addLog('Key generated (${pk.length} bytes)');

      final dbKey = Uint8List.fromList(
        List.generate(32, (_) => Random.secure().nextInt(256)),
      );

      _addLog('Initializing client...');
      final address = await xmtp.initializeClient(pk, dbKey);
      _addLog('Client address: $address');

      final inboxId = await xmtp.getClientInboxId();
      _addLog('Inbox ID: $inboxId');

      final installationId = await xmtp.getInstallationId();
      _addLog('Installation ID: ${installationId.substring(0, 16)}...');

      final state = await xmtp.inboxState(refreshFromNetwork: true);
      _addLog('Installations: ${(state['installations'] as List?)?.length ?? 0}');

      _addLog('Calling syncAll...');
      final syncResult = await xmtp.syncAll();
      _addLog('syncAll result: $syncResult');

      _addLog('Calling sendSyncRequest...');
      final syncReq = await xmtp.sendSyncRequest();
      _addLog('sendSyncRequest result: $syncReq');

      _addLog('Calling syncConsentPreferences...');
      final consentSync = await xmtp.syncConsentPreferences();
      _addLog('syncConsentPreferences result: $consentSync');

      _addLog('--- BASIC TEST PASSED ---');
    } catch (e, st) {
      _addLog('ERROR: $e');
      _addLog(st.toString().split('\n').take(3).join('\n'));
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('XMTP History Sync Test')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _running ? null : _runBasicTest,
                child: Text(_running ? 'Running...' : 'Run Basic API Test'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(_log[i], style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
