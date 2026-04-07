import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'log_file.dart' if (dart.library.io) 'log_file_io.dart';
import 'package:xmtp_plugin/xmtp_plugin.dart';

void main() {
  runApp(const XmtpTestApp());
}

class XmtpTestApp extends StatelessWidget {
  const XmtpTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XMTP Plugin Tests',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const TestRunnerPage(),
    );
  }
}

// -- Test step model ----------------------------------------------------------

enum StepStatus { pending, running, passed, failed, skipped }

class TestStep {
  final String name;
  StepStatus status;
  String detail;
  DateTime? startedAt;
  DateTime? finishedAt;

  TestStep(this.name, {this.status = StepStatus.pending, this.detail = ''});

  Duration? get elapsed =>
      startedAt == null ? null : (finishedAt ?? DateTime.now()).difference(startedAt!);
}

// -- Test runner page ---------------------------------------------------------

class TestRunnerPage extends StatefulWidget {
  const TestRunnerPage({super.key});

  @override
  State<TestRunnerPage> createState() => _TestRunnerPageState();
}

class _TestRunnerPageState extends State<TestRunnerPage> {
  final _xmtp = XmtpPlugin();
  final _steps = <TestStep>[];
  final _scrollController = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    // Auto-run tests on launch
    WidgetsBinding.instance.addPostFrameCallback((_) => _runTests());
  }

  final _logBuffer = StringBuffer();

  void _log(String line) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final entry = '[$ts] $line';
    _logBuffer.writeln(entry);
    debugPrint(entry);
    writeLog(_logBuffer.toString());
  }
  bool _done = false;

  // Ephemeral keys for three accounts + one extra for addAccount test
  late Uint8List _aliceKey, _bobKey, _charlieKey, _alice2Key;
  late Uint8List _aliceDb, _bobDb, _charlieDb, _alice2Db;
  // ignore: unused_field
  String _aliceAddress = '', _bobAddress = '', _charlieAddress = '';
  String _aliceInboxId = '', _bobInboxId = '', _charlieInboxId = '';
  String _dmTopic = '';
  String _groupTopic = '';

  Uint8List _randomDbKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }

  // -- Step helpers -----------------------------------------------------------

  TestStep _addStep(String name) {
    final step = TestStep(name);
    setState(() => _steps.add(step));
    _scrollToBottom();
    return step;
  }

  void _markRunning(TestStep step) {
    setState(() {
      step.status = StepStatus.running;
      step.startedAt = DateTime.now();
    });
    _scrollToBottom();
  }

  void _markPassed(TestStep step, [String detail = '']) {
    setState(() {
      step.status = StepStatus.passed;
      step.detail = detail;
      step.finishedAt = DateTime.now();
    });
    _log('PASS  ${step.name} (${step.elapsed?.inMilliseconds}ms) $detail');
    _scrollToBottom();
  }

  void _markFailed(TestStep step, String error) {
    setState(() {
      step.status = StepStatus.failed;
      step.detail = error;
      step.finishedAt = DateTime.now();
    });
    _log('FAIL  ${step.name} (${step.elapsed?.inMilliseconds}ms) $error');
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<bool> _runStep(String name, Future<String> Function() action) async {
    final step = _addStep(name);
    _markRunning(step);
    try {
      final detail = await action();
      _markPassed(step, detail);
      return true;
    } catch (e) {
      _markFailed(step, e.toString());
      return false;
    }
  }

  // -- Init helper: initialize a client and return (address, inboxId) ---------

  Future<(String, String)> _initClient(Uint8List privateKey, Uint8List dbKey) async {
    final address = await _xmtp.initializeClient(privateKey, dbKey, environment: 'dev');
    final inboxId = await _xmtp.getClientInboxId();
    // Small delay to let the network registration settle
    await Future.delayed(const Duration(seconds: 2));
    return (address ?? '', inboxId);
  }

  // -- Test sequence ----------------------------------------------------------

  Future<void> _runTests() async {
    setState(() {
      _running = true;
      _done = false;
      _steps.clear();
    });
    _logBuffer.clear();
    _log('=== XMTP Plugin Integration Tests ===');
    _log('Network: dev');

    // =========================================================================
    // Phase 1: Generate ephemeral keys
    // =========================================================================

    await _runStep('Generate ephemeral keys (Alice, Bob, Charlie, Alice2)', () async {
      _aliceKey = await _xmtp.generatePrivateKey();
      _bobKey = await _xmtp.generatePrivateKey();
      _charlieKey = await _xmtp.generatePrivateKey();
      _alice2Key = await _xmtp.generatePrivateKey();
      _aliceDb = _randomDbKey();
      _bobDb = _randomDbKey();
      _charlieDb = _randomDbKey();
      _alice2Db = _randomDbKey();
      return '4 key pairs generated';
    });

    // =========================================================================
    // Phase 2: Register all identities on dev network
    // =========================================================================

    var ok = await _runStep('Init Alice on dev network', () async {
      final (addr, inbox) = await _initClient(_aliceKey, _aliceDb);
      _aliceAddress = addr;
      _aliceInboxId = inbox;
      return 'address: ${addr.substring(0, 10)}... inbox: ${inbox.substring(0, 12)}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Init Bob on dev network', () async {
      final (addr, inbox) = await _initClient(_bobKey, _bobDb);
      _bobAddress = addr;
      _bobInboxId = inbox;
      return 'address: ${addr.substring(0, 10)}... inbox: ${inbox.substring(0, 12)}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Init Charlie on dev network', () async {
      final (addr, inbox) = await _initClient(_charlieKey, _charlieDb);
      _charlieAddress = addr;
      _charlieInboxId = inbox;
      return 'address: ${addr.substring(0, 10)}... inbox: ${inbox.substring(0, 12)}...';
    });
    if (!ok) return _finish();

    // =========================================================================
    // Phase 3: Alice sends DM to Bob and creates a group
    // =========================================================================

    ok = await _runStep('Switch back to Alice', () async {
      final (addr, _) = await _initClient(_aliceKey, _aliceDb);
      return 'loaded: ${addr.substring(0, 10)}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Alice: find or create DM with Bob', () async {
      final dm = await _xmtp.findOrCreateDMWithInboxId(_bobInboxId);
      _dmTopic = dm['topic'] as String? ?? '';
      return 'topic: ${_dmTopic.substring(0, min(30, _dmTopic.length))}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Alice: send text DM to Bob', () async {
      await _xmtp.sendGroupMessage(_dmTopic, 'Hello Bob, this is Alice!', 'xmtp.org', 'text');
      return 'sent';
    });
    if (!ok) return _finish();

    ok = await _runStep('Alice: create group with Bob and Charlie', () async {
      final group = await _xmtp.newGroup(
        [_bobInboxId, _charlieInboxId],
        {'name': 'Test Group', 'description': 'Integration test group'},
      );
      _groupTopic = group['topic'] as String? ?? '';
      final name = group['name'] ?? 'unnamed';
      return 'name: $name, topic: ${_groupTopic.substring(0, min(30, _groupTopic.length))}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Alice: send message to group', () async {
      await _xmtp.sendGroupMessage(_groupTopic, 'Hey team, Alice here!', 'xmtp.org', 'text');
      return 'sent';
    });
    if (!ok) return _finish();

    // Wait for network propagation before switching users
    ok = await _runStep('Wait for network propagation', () async {
      await Future.delayed(const Duration(seconds: 8));
      return 'waited 8s';
    });
    if (!ok) return _finish();

    // =========================================================================
    // Phase 4: Switch to Bob, verify received messages
    // =========================================================================

    ok = await _runStep('Switch to Bob', () async {
      final (addr, _) = await _initClient(_bobKey, _bobDb);
      return 'loaded: ${addr.substring(0, 10)}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Bob: sync conversations (with retry)', () async {
      for (var attempt = 1; attempt <= 5; attempt++) {
        await _xmtp.syncAll(consentStates: ['allowed', 'unknown']);
        final dms = await _xmtp.listDms();
        final groups = await _xmtp.listGroups();
        if (dms.isNotEmpty || groups.isNotEmpty) {
          return 'attempt $attempt: found ${dms.length} DM(s), ${groups.length} group(s)';
        }
        await Future.delayed(const Duration(seconds: 5));
      }
      return 'found 0 after 5 attempts — network may be slow';
    });
    if (!ok) return _finish();

    ok = await _runStep('Bob: check DM from Alice', () async {
      // List DMs — should find the one Alice created after sync
      final dms = await _xmtp.listDms();
      String bobDmTopic = '';
      // Find DM by peer inbox ID
      for (final dm in dms) {
        if (dm['peerInboxId'] == _aliceInboxId) {
          bobDmTopic = dm['topic'] as String? ?? '';
          break;
        }
      }
      // Fallback: create from Bob's side
      if (bobDmTopic.isEmpty) {
        final dm = await _xmtp.findOrCreateDMWithInboxId(_aliceInboxId);
        bobDmTopic = dm['topic'] as String? ?? '';
      }
      await _xmtp.syncConversation(bobDmTopic);
      await Future.delayed(const Duration(seconds: 3));
      final since = DateTime.now().subtract(const Duration(minutes: 10));
      final messages = await _xmtp.getMessagesAfterDateByTopic(bobDmTopic, since);
      final textMessages = messages.where((m) {
        final content = m['content'];
        final decoded = m['decodedContent'];
        return (content is String && content.contains('Alice')) ||
               (decoded is String && decoded.contains('Alice'));
      }).toList();
      if (textMessages.isEmpty) {
        final preview = messages.take(3).map((m) =>
          'type=${m['type']}, content=${m['content']?.toString().substring(0, min(40, (m['content']?.toString().length ?? 0)))}'
        ).join(' | ');
        throw Exception('No DM from Alice. Got ${messages.length} msg(s), topic=$bobDmTopic, dms=${dms.length}. Preview: $preview');
      }
      return 'found ${textMessages.length} message(s) from Alice (topic=$bobDmTopic)';
    });
    if (!ok) return _finish();

    ok = await _runStep('Bob: check group message from Alice', () async {
      await _xmtp.syncConversation(_groupTopic);
      await Future.delayed(const Duration(seconds: 3));
      final since = DateTime.now().subtract(const Duration(minutes: 10));
      final messages = await _xmtp.getMessagesAfterDateByTopic(_groupTopic, since);
      final textMessages = messages.where((m) {
        final content = m['content'];
        final decoded = m['decodedContent'];
        return (content is String && content.contains('team')) ||
               (decoded is String && decoded.contains('team'));
      }).toList();
      if (textMessages.isEmpty) {
        final preview = messages.take(3).map((m) =>
          'type=${m['type']}, content=${m['content']?.toString().substring(0, min(40, (m['content']?.toString().length ?? 0)))}'
        ).join(' | ');
        throw Exception('No group msg from Alice. Got ${messages.length} msg(s). Preview: $preview');
      }
      return 'found ${textMessages.length} group message(s)';
    });
    if (!ok) return _finish();

    // =========================================================================
    // Phase 5: Switch to Charlie, verify group message
    // =========================================================================

    ok = await _runStep('Switch to Charlie', () async {
      final (addr, _) = await _initClient(_charlieKey, _charlieDb);
      return 'loaded: ${addr.substring(0, 10)}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Charlie: sync conversations (with retry)', () async {
      for (var attempt = 1; attempt <= 5; attempt++) {
        await _xmtp.syncAll(consentStates: ['allowed', 'unknown']);
        final groups = await _xmtp.listGroups();
        if (groups.isNotEmpty) {
          return 'attempt $attempt: found ${groups.length} group(s)';
        }
        await Future.delayed(const Duration(seconds: 5));
      }
      return 'found 0 group(s) after 5 attempts';
    });
    if (!ok) return _finish();

    ok = await _runStep('Charlie: check group message from Alice', () async {
      await _xmtp.syncConversation(_groupTopic);
      await Future.delayed(const Duration(seconds: 3));
      final since = DateTime.now().subtract(const Duration(minutes: 10));
      final messages = await _xmtp.getMessagesAfterDateByTopic(_groupTopic, since);
      final textMessages = messages.where((m) {
        final content = m['content'];
        final decoded = m['decodedContent'];
        return (content is String && content.contains('team')) ||
               (decoded is String && decoded.contains('team'));
      }).toList();
      if (textMessages.isEmpty) {
        final preview = messages.take(3).map((m) =>
          'type=${m['type']}, content=${m['content']?.toString().substring(0, min(40, (m['content']?.toString().length ?? 0)))}'
        ).join(' | ');
        throw Exception('No group msg. Got ${messages.length} msg(s). Preview: $preview');
      }
      return 'found ${textMessages.length} group message(s)';
    });
    if (!ok) return _finish();

    // =========================================================================
    // Phase 6: Add Alice2 key to Alice's inbox, verify shared identity
    // =========================================================================

    ok = await _runStep('Switch back to Alice', () async {
      final (addr, _) = await _initClient(_aliceKey, _aliceDb);
      return 'loaded: ${addr.substring(0, 10)}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Alice: add Alice2 key to her inbox (addAccount)', () async {
      await _xmtp.addAccount(_alice2Key, allowReassignInboxId: true);
      return 'Alice2 key linked to Alice inbox';
    });
    if (!ok) return _finish();

    ok = await _runStep('Alice: verify inbox state shows both identities', () async {
      final state = await _xmtp.inboxState(refreshFromNetwork: true);
      final identities = state['identities'] as List? ?? [];
      if (identities.length < 2) {
        throw Exception('Expected at least 2 identities, got ${identities.length}: $identities');
      }
      return '${identities.length} identities linked to inbox';
    });
    if (!ok) return _finish();

    // =========================================================================
    // Phase 7: Init as Alice2, verify it shares Alice's inbox and messages
    // =========================================================================

    ok = await _runStep('Init Alice2 on dev network', () async {
      final (addr, inbox) = await _initClient(_alice2Key, _aliceDb);
      return 'address: ${addr.substring(0, 10)}... inbox: ${inbox.substring(0, 12)}...';
    });
    if (!ok) return _finish();

    ok = await _runStep('Alice2: verify same inbox ID as Alice', () async {
      final alice2Inbox = await _xmtp.getClientInboxId();
      if (alice2Inbox != _aliceInboxId) {
        throw Exception(
          'Inbox mismatch!\n'
          'Alice:  $_aliceInboxId\n'
          'Alice2: $alice2Inbox',
        );
      }
      return 'confirmed: both keys share inbox ${alice2Inbox.substring(0, 12)}...';
    });
    if (!ok) return _finish();

    _finish();
  }

  void _finish() {
    final passed = _steps.where((s) => s.status == StepStatus.passed).length;
    final failed = _steps.where((s) => s.status == StepStatus.failed).length;
    _log('=== DONE: $passed passed, $failed failed, ${_steps.length} total ===');
    final logPath = getLogPath();
    if (logPath != null) _log('Log: $logPath');
    setState(() {
      _running = false;
      _done = true;
    });
  }

  // -- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final passed = _steps.where((s) => s.status == StepStatus.passed).length;
    final failed = _steps.where((s) => s.status == StepStatus.failed).length;
    final total = _steps.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('XMTP Plugin Integration Tests'),
        actions: [
          // Copy log button
          if (_steps.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy log to clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _logBuffer.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log copied to clipboard'), duration: Duration(seconds: 1)),
                );
              },
            ),
          if (_done)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '$passed/$total passed${failed > 0 ? ' ($failed failed)' : ''}',
                  style: TextStyle(
                    color: failed > 0 ? Colors.red.shade300 : Colors.green.shade300,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Network badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.indigo.withValues(alpha: 0.15),
            child: const Text(
              'Network: production (grpc.production.xmtp.network)',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          // Test steps list
          Expanded(
            child: _steps.isEmpty
                ? const Center(
                    child: Text(
                      'Press RUN to start integration tests',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) => _StepTile(step: _steps[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _running ? null : _runTests,
        icon: _running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_running ? 'Running...' : (_done ? 'Run Again' : 'Run')),
      ),
    );
  }
}

// -- Step tile widget ---------------------------------------------------------

class _StepTile extends StatelessWidget {
  final TestStep step;
  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final icon = switch (step.status) {
      StepStatus.pending => const Icon(Icons.circle_outlined, color: Colors.white24, size: 20),
      StepStatus.running => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
        ),
      StepStatus.passed => const Icon(Icons.check_circle, color: Colors.green, size: 20),
      StepStatus.failed => const Icon(Icons.cancel, color: Colors.red, size: 20),
      StepStatus.skipped => const Icon(Icons.skip_next, color: Colors.white38, size: 20),
    };

    final elapsed = step.elapsed;
    final timeStr = elapsed != null ? '${elapsed.inMilliseconds}ms' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: icon,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: step.status == StepStatus.failed ? Colors.red.shade300 : Colors.white,
                  ),
                ),
                if (step.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.detail,
                      style: TextStyle(
                        fontSize: 11,
                        color: step.status == StepStatus.failed
                            ? Colors.red.shade200
                            : Colors.white54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (timeStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                timeStr,
                style: const TextStyle(fontSize: 11, color: Colors.white30),
              ),
            ),
        ],
      ),
    );
  }
}
