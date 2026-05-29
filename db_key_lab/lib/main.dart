import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmtp_plugin/xmtp_plugin.dart';

/// On-device lab for the XMTP key + DB-key lifecycle.
///
/// One screen, top = actions, bottom = live log (so "nothing happened" is never
/// ambiguous). Runs against the XMTP **production** network. The DB key is the
/// 32-byte AES key that encrypts the local libxmtp `xmtp.db3`; the identity key
/// is the secp256k1 private key that owns the inbox.
///
/// What you can exercise:
///   - Generate an identity key + a DB key
///   - Export both (identity as hex, DB key as base64) and copy them
///   - Import either by pasting it back
///   - Initialize the client (creates/opens the encrypted local DB)
///   - Resolve the inbox ID for an address from the network (no client needed)
///   - Delete the local DB
///   - One-tap mismatch recovery: resolve inbox -> delete DB -> re-init
void main() => runApp(const DbKeyLabApp());

const String kEnvironment = 'production';

class DbKeyLabApp extends StatelessWidget {
  const DbKeyLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XMTP DB Key Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const LabPage(),
    );
  }
}

class LabPage extends StatefulWidget {
  const LabPage({super.key});

  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  final _xmtp = XmtpPlugin();

  // Current working material.
  Uint8List? _identityKey; // secp256k1 private key (raw bytes)
  Uint8List? _dbKey; // 32-byte AES DB encryption key
  String? _address; // set after a successful init
  String? _inboxId; // set after a successful init

  // Import / delete inputs.
  final _importIdentityCtrl = TextEditingController();
  final _importDbKeyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _inboxCtrl = TextEditingController();

  bool _busy = false;

  // -- Logging ---------------------------------------------------------------

  final _log = <String>[];
  final _logScroll = ScrollController();

  void _logLine(String line, {bool error = false}) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    setState(() => _log.add('${error ? '[!] ' : ''}[$ts] $line'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  // -- Hex helpers (no dart:convert hex codec) -------------------------------

  String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Uint8List _fromHex(String input) {
    var s = input.trim();
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    s = s.replaceAll(RegExp(r'\s'), '');
    if (s.length.isOdd) {
      throw const FormatException('Hex string has an odd length');
    }
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  Uint8List _randomDbKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }

  // -- Action runner ---------------------------------------------------------

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    _logLine('> $label');
    try {
      await action();
    } on PlatformException catch (e) {
      _logLine('$label FAILED: [${e.code}] ${e.message}', error: true);
      _maybeMismatch(e);
    } catch (e) {
      _logLine('$label FAILED: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _maybeMismatch(PlatformException e) {
    final msg = (e.message ?? '').toLowerCase();
    final looksLikeMismatch = msg.contains('cipher') ||
        msg.contains('not a database') ||
        msg.contains('decrypt') ||
        msg.contains('mismatch') ||
        msg.contains('hmac') ||
        msg.contains('malformed');
    if (looksLikeMismatch) {
      _logLine(
        'Looks like a DB-key MISMATCH: the on-disk DB was encrypted with a '
        'different key. Use "Mismatch recovery" below to delete it and retry.',
        error: true,
      );
    }
  }

  // -- Actions ---------------------------------------------------------------

  Future<void> _generateIdentity() => _run('Generate identity key', () async {
        final key = await _xmtp.generatePrivateKey();
        setState(() => _identityKey = key);
        _logLine('identity key (${key.length} bytes): 0x${_hex(key)}');
      });

  Future<void> _generateDbKey() => _run('Generate DB key', () async {
        final key = _randomDbKey();
        setState(() => _dbKey = key);
        _logLine('DB key (base64): ${base64Encode(key)}');
      });

  Future<void> _importIdentity() => _run('Import identity key (hex)', () async {
        final key = _fromHex(_importIdentityCtrl.text);
        setState(() => _identityKey = key);
        _logLine('identity key set (${key.length} bytes)');
      });

  Future<void> _importDbKey() => _run('Import DB key (base64)', () async {
        final key = Uint8List.fromList(base64Decode(_importDbKeyCtrl.text.trim()));
        if (key.length != 32) {
          throw FormatException('DB key must be 32 bytes, got ${key.length}');
        }
        setState(() => _dbKey = key);
        _logLine('DB key set (32 bytes)');
      });

  Future<void> _initClient() => _run('Initialize client ($kEnvironment)', () async {
        final id = _identityKey;
        final db = _dbKey;
        if (id == null || db == null) {
          throw StateError('Need both an identity key and a DB key first.');
        }
        final address =
            await _xmtp.initializeClient(id, db, environment: kEnvironment);
        final inboxId = await _xmtp.getClientInboxId();
        setState(() {
          _address = address;
          _inboxId = inboxId;
          _addressCtrl.text = address ?? '';
          _inboxCtrl.text = inboxId;
        });
        _logLine('OK address: $address');
        _logLine('OK inboxId: $inboxId');
      });

  Future<void> _resolveInbox() => _run('Resolve inbox ID from address', () async {
        final addr = _addressCtrl.text.trim();
        if (addr.isEmpty) throw StateError('Enter an address to resolve.');
        final inboxId = await XmtpPlugin.staticGetInboxIdForAddress(
          addr,
          environment: kEnvironment,
        );
        if (inboxId == null) {
          _logLine('No inbox found on the network for $addr');
        } else {
          setState(() => _inboxCtrl.text = inboxId);
          _logLine('inboxId: $inboxId');
        }
      });

  Future<void> _deleteDb() => _run('Delete local DB', () async {
        final addr = _addressCtrl.text.trim();
        final inboxId = _inboxCtrl.text.trim();
        if (inboxId.isEmpty) {
          throw StateError('Need an inbox ID. Resolve or init first.');
        }
        await XmtpPlugin.staticDeleteLocalDatabase(
          addr,
          inboxId,
          environment: kEnvironment,
        );
        _logLine('delete returned OK (files removed if they existed)');
      });

  Future<void> _mismatchRecovery() =>
      _run('Mismatch recovery (resolve -> delete -> re-init)', () async {
        final id = _identityKey;
        final db = _dbKey;
        if (id == null || db == null) {
          throw StateError('Need both an identity key and a DB key first.');
        }
        // 1. Resolve the real inbox ID from the network (no client needed).
        var addr = _addressCtrl.text.trim();
        if (addr.isEmpty) addr = _address ?? '';
        if (addr.isEmpty) {
          throw StateError('Enter the wallet address (or init once) first.');
        }
        _logLine('  resolving inbox for $addr ...');
        final inboxId = await XmtpPlugin.staticGetInboxIdForAddress(
          addr,
          environment: kEnvironment,
        );
        if (inboxId == null) {
          throw StateError('No inbox on network for $addr — nothing to delete.');
        }
        setState(() => _inboxCtrl.text = inboxId);
        _logLine('  inboxId: $inboxId');
        // 2. Delete the wrong-key local DB.
        _logLine('  deleting local DB ...');
        await XmtpPlugin.staticDeleteLocalDatabase(
          addr,
          inboxId,
          environment: kEnvironment,
        );
        // 3. Re-init — should now build a fresh DB with the current key.
        _logLine('  re-initializing client ...');
        final address =
            await _xmtp.initializeClient(id, db, environment: kEnvironment);
        final newInbox = await _xmtp.getClientInboxId();
        setState(() {
          _address = address;
          _inboxId = newInbox;
          _addressCtrl.text = address ?? '';
          _inboxCtrl.text = newInbox;
        });
        _logLine('  recovered. address: $address inboxId: $newInbox');
      });

  void _copy(String value, String what) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what copied'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  void dispose() {
    _importIdentityCtrl.dispose();
    _importDbKeyCtrl.dispose();
    _addressCtrl.dispose();
    _inboxCtrl.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  // -- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XMTP DB Key Lab'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            alignment: Alignment.centerLeft,
            child: Text('network: $kEnvironment',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy log',
            icon: const Icon(Icons.copy_all),
            onPressed: () => _copy(_log.join('\n'), 'Log'),
          ),
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(_log.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _keysCard(),
                const SizedBox(height: 10),
                _clientCard(),
                const SizedBox(height: 10),
                _deleteCard(),
              ],
            ),
          ),
          _logPanel(),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _keyDisplay(String label, String? value, {VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ),
          Expanded(
            child: SelectableText(
              value ?? '— none —',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: value == null ? Colors.white38 : Colors.tealAccent,
              ),
            ),
          ),
          if (value != null && onCopy != null)
            InkWell(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy, size: 16, color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _keysCard() {
    final idHex = _identityKey == null ? null : '0x${_hex(_identityKey!)}';
    final dbB64 = _dbKey == null ? null : base64Encode(_dbKey!);
    return _section('1. Keys (generate / export / import)', [
      _keyDisplay('identity', idHex,
          onCopy: idHex == null ? null : () => _copy(idHex, 'Identity key')),
      _keyDisplay('db key', dbB64,
          onCopy: dbB64 == null ? null : () => _copy(dbB64, 'DB key')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _generateIdentity,
          icon: const Icon(Icons.vpn_key, size: 18),
          label: const Text('Gen identity'),
        ),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _generateDbKey,
          icon: const Icon(Icons.enhanced_encryption, size: 18),
          label: const Text('Gen DB key'),
        ),
      ]),
      const Divider(height: 24),
      TextField(
        controller: _importIdentityCtrl,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Paste identity key (hex)',
          border: const OutlineInputBorder(),
          suffixIcon: TextButton(
            onPressed: _busy ? null : _importIdentity,
            child: const Text('Set'),
          ),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _importDbKeyCtrl,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Paste DB key (base64)',
          border: const OutlineInputBorder(),
          suffixIcon: TextButton(
            onPressed: _busy ? null : _importDbKey,
            child: const Text('Set'),
          ),
        ),
      ),
    ]);
  }

  Widget _clientCard() {
    return _section('2. Client', [
      _keyDisplay('address', _address),
      _keyDisplay('inboxId', _inboxId),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _busy ? null : _initClient,
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('Initialize client'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text(
          'Opens (or creates) the local encrypted DB with the current identity + DB key.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ),
    ]);
  }

  Widget _deleteCard() {
    return _section('3. Delete / recover local DB', [
      TextField(
        controller: _addressCtrl,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Wallet address',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _inboxCtrl,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Inbox ID',
          border: const OutlineInputBorder(),
          suffixIcon: TextButton(
            onPressed: _busy ? null : _resolveInbox,
            child: const Text('Resolve'),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _deleteDb,
          icon: const Icon(Icons.delete_forever, size: 18),
          label: const Text('Delete local DB'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
          onPressed: _busy ? null : _mismatchRecovery,
          icon: const Icon(Icons.healing, size: 18),
          label: const Text('Mismatch recovery'),
        ),
      ]),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text(
          'Recovery = resolve inbox from network, delete the local DB, then re-init '
          'with the current key. This is the exact "erase & continue" path.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ),
    ]);
  }

  Widget _logPanel() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF101014),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Text('LOG',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: Colors.white38,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _log.isEmpty
                ? const Center(
                    child: Text('actions appear here',
                        style: TextStyle(color: Colors.white24, fontSize: 12)))
                : ListView.builder(
                    controller: _logScroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _log.length,
                    itemBuilder: (context, i) {
                      final line = _log[i];
                      final isErr = line.startsWith('[!]');
                      return Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: isErr ? Colors.redAccent : Colors.white70,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
