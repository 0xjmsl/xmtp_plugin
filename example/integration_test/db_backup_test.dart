/// XMTP Local-Database Backup Integration Tests (dev network, throwaway keys)
///
///  DB1 — RAW DB-FILE BACKUP/RESTORE: copy the .db3 file + keep the same
///        32-byte dbEncryptionKey → restore → initializeClient opens the
///        EXISTING installation (no registration, no inbox-slot burn) and the
///        local message history is intact. This is the "full DB download"
///        user flow's core primitive: the network sees the same installation.
///        (Contrast: importing an SDK archive onto a fresh DB = NEW
///        installation = burns one of the inbox's 10 slots.)
///
///  T10 — SDK ARCHIVE ROUND-TRIP: exportArchive → file is non-trivial (the
///        55-byte empty-elements trap) → archiveMetadata matches → wrong
///        password rejected → wipe → fresh install → importArchive completes.
///        Note (wiki: integration_tests § false-PASS trap): post-import
///        message counts on a live client are NOT proof of import — the
///        network can re-hydrate — so the assertions here are on the FILE and
///        the typed failures; counts are printed for information only.
///
/// Run with:
///   cd example && flutter test integration_test/db_backup_test.dart -d windows
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xmtp_plugin/xmtp_plugin.dart';
import 'package:xmtp_plugin/codecs.dart';

const env = 'dev';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Uint8List randomDbKey() =>
      Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));

  XmtpPlugin createXmtp() {
    final xmtp = XmtpPlugin();
    xmtp.registerCodec(TextCodec());
    return xmtp;
  }

  /// Windows DB file set for an address (mirrors rust/src/api/client.rs:172).
  List<File> dbFilesFor(String address) {
    final base =
        '${Directory.systemTemp.path}\\xmtp_plugin\\${address.substring(2, 10)}.db3';
    return [File(base), File('$base-wal'), File('$base-shm')];
  }

  testWidgets('DB1: raw DB file + key backup/restore = same installation',
      (tester) async {
    final xmtp = createXmtp();

    // Peer inbox B so A has a real conversation.
    final pkB = await xmtp.generatePrivateKey();
    await xmtp.initializeClient(pkB, randomDbKey(), environment: env);
    final bobInboxId = await xmtp.getClientInboxId();
    final bobAddress = await xmtp.getClientAddress();
    expect(await xmtp.closeClient(), isTrue);

    // Inbox A: register, converse, remember the installation.
    final pkA = await xmtp.generatePrivateKey();
    final dbKeyA = randomDbKey();
    final addressA =
        (await xmtp.initializeClient(pkA, dbKeyA, environment: env))!;
    final inboxIdA = await xmtp.getClientInboxId();
    final installA1 = await xmtp.getInstallationId();
    await xmtp.findOrCreateDMWithInboxId(bobInboxId);
    await xmtp.sendMessage(bobAddress, 'raw-db backup msg 1', 'xmtp.org', 'text');
    await xmtp.sendMessage(bobAddress, 'raw-db backup msg 2', 'xmtp.org', 'text');
    await xmtp.syncAll();
    final msgsBefore = await xmtp.getMessagesAfterDate(
        bobAddress, DateTime.now().subtract(const Duration(minutes: 5)));
    expect(msgsBefore.length, greaterThanOrEqualTo(2));
    print('A: $addressA install=${installA1.substring(0, 16)}… '
        'messages=${msgsBefore.length}');

    // "Download the backup": close the client, copy the DB file set.
    expect(await xmtp.closeClient(), isTrue);
    final backupDir = await Directory.systemTemp.createTemp('xmtp_raw_backup_');
    final backups = <String, String>{};
    for (final f in dbFilesFor(addressA)) {
      if (f.existsSync()) {
        final dest = '${backupDir.path}\\${f.uri.pathSegments.last}';
        f.copySync(dest);
        backups[f.path] = dest;
      }
    }
    expect(backups, isNotEmpty, reason: 'the .db3 file must exist to back up');
    print('Backed up ${backups.length} DB file(s) to ${backupDir.path}');

    // "Device reset": delete the local DB.
    await XmtpPlugin.staticDeleteLocalDatabase(addressA, inboxIdA,
        environment: env);
    expect(dbFilesFor(addressA).first.existsSync(), isFalse,
        reason: 'local DB must be gone after the wipe');

    // "Restore": put the files back, init with the SAME dbEncryptionKey.
    for (final entry in backups.entries) {
      File(entry.value).copySync(entry.key);
    }
    await xmtp.initializeClient(pkA, dbKeyA, environment: env);
    final installRestored = await xmtp.getInstallationId();
    expect(installRestored, installA1,
        reason: 'restored DB must open the SAME installation (no slot burn)');
    final state = await xmtp.inboxState(refreshFromNetwork: true);
    expect((state['installations'] as List).length, 1,
        reason: 'the network must still see exactly 1 installation');
    final msgsAfter = await xmtp.getMessagesAfterDate(
        bobAddress, DateTime.now().subtract(const Duration(minutes: 5)));
    expect(msgsAfter.length, greaterThanOrEqualTo(msgsBefore.length),
        reason: 'local history must survive the raw-DB restore');
    print('DB1 PASS: same installation ${installRestored.substring(0, 16)}…, '
        '1 network installation, ${msgsAfter.length} messages intact');

    await backupDir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('DB2: plugin static exists/export/import round-trip',
      (tester) async {
    final xmtp = createXmtp();

    final pk = await xmtp.generatePrivateKey();
    final dbKey = randomDbKey();
    final address =
        (await xmtp.initializeClient(pk, dbKey, environment: env))!;
    final inboxId = await xmtp.getClientInboxId();
    final install1 = await xmtp.getInstallationId();

    expect(
        await XmtpPlugin.staticLocalDatabaseExists(address,
            inboxId: inboxId, environment: env),
        isTrue,
        reason: 'DB must exist while the identity is set up');

    // Export via the plugin API (client closed first).
    expect(await xmtp.closeClient(), isTrue);
    final dir = await Directory.systemTemp.createTemp('xmtp_static_backup_');
    final backupPath = '${dir.path}\\exported.db3';
    await XmtpPlugin.staticExportLocalDatabase(backupPath, address,
        inboxId: inboxId, environment: env);
    expect(File(backupPath).existsSync(), isTrue);
    expect(File(backupPath).lengthSync(), greaterThan(0));

    // Import over an existing DB must refuse (restore is always explicit).
    var importOverExistingThrew = false;
    try {
      await XmtpPlugin.staticImportLocalDatabase(backupPath, address,
          inboxId: inboxId, environment: env);
    } catch (e) {
      importOverExistingThrew = true;
      print('DB2: import over existing DB refused with: $e');
    }
    expect(importOverExistingThrew, isTrue);

    // Wipe → exists false → import → exists true → same installation.
    await XmtpPlugin.staticDeleteLocalDatabase(address, inboxId,
        environment: env);
    expect(
        await XmtpPlugin.staticLocalDatabaseExists(address,
            inboxId: inboxId, environment: env),
        isFalse,
        reason: 'DB must be gone after the wipe');
    await XmtpPlugin.staticImportLocalDatabase(backupPath, address,
        inboxId: inboxId, environment: env);
    expect(
        await XmtpPlugin.staticLocalDatabaseExists(address,
            inboxId: inboxId, environment: env),
        isTrue,
        reason: 'DB must be back after the import');
    await xmtp.initializeClient(pk, dbKey, environment: env);
    expect(await xmtp.getInstallationId(), install1,
        reason: 'restored DB must open the SAME installation');
    print('DB2 PASS: static exists/export/import round-trip, installation '
        '${install1.substring(0, 16)}… preserved');

    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('T10: SDK archive export/metadata/import round-trip',
      (tester) async {
    final xmtp = createXmtp();

    // Peer + inbox with content.
    final pkB = await xmtp.generatePrivateKey();
    await xmtp.initializeClient(pkB, randomDbKey(), environment: env);
    final bobInboxId = await xmtp.getClientInboxId();
    final bobAddress = await xmtp.getClientAddress();
    expect(await xmtp.closeClient(), isTrue);

    final pkA = await xmtp.generatePrivateKey();
    final addressA =
        (await xmtp.initializeClient(pkA, randomDbKey(), environment: env))!;
    final inboxIdA = await xmtp.getClientInboxId();
    await xmtp.findOrCreateDMWithInboxId(bobInboxId);
    await xmtp.sendMessage(bobAddress, 'archive msg 1', 'xmtp.org', 'text');
    await xmtp.sendMessage(bobAddress, 'archive msg 2', 'xmtp.org', 'text');
    await xmtp.syncAll();

    // Export (default elements → normalized to messages+consent everywhere).
    final dir = await Directory.systemTemp.createTemp('xmtp_archive_');
    final path = '${dir.path}\\backup.xmtpBak';
    const password = 'correct horse battery staple';
    await xmtp.exportArchive(path, password);
    final size = File(path).lengthSync();
    print('Archive written: $size bytes');
    expect(size, greaterThan(1000),
        reason: 'a metadata-only (empty-elements) archive is ~55 bytes — '
            'the export must contain real frames');

    // Metadata reads back with the right password.
    final meta = await xmtp.archiveMetadata(path, password);
    print('Metadata: version=${meta.backupVersion} elements=${meta.elements} '
        'exportedAtNs=${meta.exportedAtNs}');
    expect(meta.exportedAtNs, greaterThan(0));
    expect(meta.elements,
        containsAll([BackupElement.messages, BackupElement.consent]),
        reason: 'empty-elements default must normalize to BOTH elements');

    // Wrong password must fail loudly, not decode garbage.
    var wrongPasswordThrew = false;
    try {
      await xmtp.archiveMetadata(path, 'wrong password');
    } catch (e) {
      wrongPasswordThrew = true;
      print('Wrong password rejected with: $e');
    }
    expect(wrongPasswordThrew, isTrue);

    // Wipe + fresh install (burns a throwaway slot — that is the point of
    // the raw-DB flow existing as the slot-free alternative).
    expect(await xmtp.closeClient(), isTrue);
    await XmtpPlugin.staticDeleteLocalDatabase(addressA, inboxIdA,
        environment: env);
    await xmtp.initializeClient(pkA, randomDbKey(), environment: env);
    final stateBefore = await xmtp.inboxState(refreshFromNetwork: true);
    print('Installations after fresh re-init: '
        '${(stateBefore['installations'] as List).length} (archive restore '
        'creates a NEW installation — slot burned)');

    // Import completes against the same inbox. (The count below is
    // informational only — see the false-PASS trap note; the DM may not even
    // be listable locally until the next sync.)
    await xmtp.importArchive(path, password);
    var visible = 'n/a';
    try {
      await xmtp.syncAll();
      final msgs = await xmtp.getMessagesAfterDate(
          bobAddress, DateTime.now().subtract(const Duration(minutes: 10)));
      visible = '${msgs.length}';
    } catch (e) {
      visible = 'unavailable (${e.runtimeType})';
    }
    print('T10 PASS: import completed; local messages now visible: '
        '$visible (informational — see false-PASS trap note)');

    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
