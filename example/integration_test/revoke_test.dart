/// XMTP Revocation Integration Tests
///
/// Verifies the revocation wiring end-to-end against the XMTP **dev** network
/// using ephemeral throwaway keys (generated per run, never persisted):
///
///  R1 — revokeAllOtherInstallations (instance method, needs active client):
///       drive one ephemeral inbox to 2 installations, revoke-all, assert 1.
///  R1b — closeClient + re-init from the EXISTING DB must reuse the same
///       installation (the raw-DB-restore primitive: no new slot burned).
///  R2 — staticRevokeInstallations (true static path, target != active client):
///       revoke another inbox's installation while a different client is
///       active; includes a wrong-signer negative pin.
///
/// Windows singleton caveat: the Rust layer keys the DB file on the wallet
/// address (temp_dir/xmtp_plugin/<addr[2..10]>.db3) and holds ONE client per
/// process. To mint a second installation for the same key we closeClient()
/// (releases the DB file), staticDeleteLocalDatabase, then re-init → fresh DB
/// → a new installation registers.
///
/// Run with:
///   cd example && flutter test integration_test/revoke_test.dart -d windows
library;

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

  Future<List> installationsOf(XmtpPlugin xmtp) async {
    final state = await xmtp.inboxState(refreshFromNetwork: true);
    return state['installations'] as List;
  }

  testWidgets('R1+R2: revoke-all and static revoke are correctly wired',
      (tester) async {
    final xmtp = createXmtp();

    // ---- Ephemeral inbox A, installation #1 --------------------------------
    final pkA = await xmtp.generatePrivateKey();
    final addressA =
        await xmtp.initializeClient(pkA, randomDbKey(), environment: env);
    expect(addressA, isNotNull);
    final inboxIdA = await xmtp.getClientInboxId();
    final installA1 = await xmtp.getInstallationId();
    var installs = await installationsOf(xmtp);
    expect(installs.length, 1,
        reason: 'fresh inbox A must start with exactly 1 installation');
    print('A: address=$addressA inbox=$inboxIdA install1=${installA1.substring(0, 16)}…');

    // ---- Second installation for A: close, delete DB, re-init --------------
    expect(await xmtp.closeClient(), isTrue,
        reason: 'closeClient must report an active client was closed');
    await XmtpPlugin.staticDeleteLocalDatabase(addressA!, inboxIdA,
        environment: env);
    final dbKeyA2 = randomDbKey();
    final addressA2 =
        await xmtp.initializeClient(pkA, dbKeyA2, environment: env);
    expect(addressA2, addressA, reason: 'same key must yield same address');
    expect(await xmtp.getClientInboxId(), inboxIdA,
        reason: 'registered address must resolve to the same inbox id');
    final installA2 = await xmtp.getInstallationId();
    expect(installA2, isNot(installA1),
        reason: 'fresh DB must register a NEW installation');
    installs = await installationsOf(xmtp);
    print('A after re-init: ${installs.length} installations '
        '(${installs.map((i) => (i['id'] as String).substring(0, 8)).join(', ')})');
    expect(installs.length, 2,
        reason: 'inbox A must now have 2 installations');
    final ids = installs.map((i) => i['id'] as String).toSet();
    expect(ids, containsAll({installA1, installA2}));

    // ---- R1: revokeAllOtherInstallations -----------------------------------
    await xmtp.revokeAllOtherInstallations(pkA);
    installs = await installationsOf(xmtp);
    expect(installs.length, 1,
        reason: 'revoke-all must leave exactly the current installation');
    expect(installs.single['id'], installA2,
        reason: 'the surviving installation must be the current one');
    print('R1 PASS: revokeAllOtherInstallations revoked '
        '${installA1.substring(0, 16)}…, kept ${installA2.substring(0, 16)}…');

    // ---- Ephemeral inbox B (target for the static revoke) ------------------
    expect(await xmtp.closeClient(), isTrue);
    final pkB = await xmtp.generatePrivateKey();
    final addressB =
        await xmtp.initializeClient(pkB, randomDbKey(), environment: env);
    final inboxIdB = await xmtp.getClientInboxId();
    final installB1 = await xmtp.getInstallationId();
    expect(inboxIdB, isNot(inboxIdA));
    print('B: address=$addressB inbox=$inboxIdB install=${installB1.substring(0, 16)}…');

    // ---- R1b: re-open A from its EXISTING DB — same installation ----------
    // (The raw-DB-restore primitive: DB file + same dbKey present → init must
    // NOT register a new installation.)
    expect(await xmtp.closeClient(), isTrue);
    await xmtp.initializeClient(pkA, dbKeyA2, environment: env);
    expect(await xmtp.getInstallationId(), installA2,
        reason: 're-init from existing DB must reuse the same installation');
    installs = await installationsOf(xmtp);
    expect(installs.length, 1,
        reason: 're-init from existing DB must NOT burn an inbox slot');
    print('R1b PASS: existing-DB re-init reused installation '
        '${installA2.substring(0, 16)}… (no new slot)');

    // ---- R2: static revoke of inbox B while client A is active -------------
    var statesB = await XmtpPlugin.staticInboxStatesForInboxIds([inboxIdB]);
    expect(statesB.single['installations'], hasLength(1));
    expect(statesB.single['installations'][0]['id'], installB1);

    // Negative pin: signer A is NOT inbox B's recovery key → must fail and
    // must not revoke anything.
    var wrongSignerThrew = false;
    try {
      await XmtpPlugin.staticRevokeInstallations(
        signerPrivateKey: pkA,
        inboxId: inboxIdB,
        installationIds: [installB1],
      );
    } catch (e) {
      wrongSignerThrew = true;
      print('R2 negative pin: wrong signer rejected with: $e');
    }
    expect(wrongSignerThrew, isTrue,
        reason: 'a non-recovery signer must be rejected');
    statesB = await XmtpPlugin.staticInboxStatesForInboxIds([inboxIdB]);
    expect(statesB.single['installations'], hasLength(1),
        reason: 'wrong-signer attempt must not revoke anything');

    // Correct signer: revoke B's only installation via the true static path.
    await XmtpPlugin.staticRevokeInstallations(
      signerPrivateKey: pkB,
      inboxId: inboxIdB,
      installationIds: [installB1],
    );
    statesB = await XmtpPlugin.staticInboxStatesForInboxIds([inboxIdB]);
    print('R2: inbox B installations after static revoke: '
        '${(statesB.single['installations'] as List).length}');
    expect(statesB.single['installations'], isEmpty,
        reason: 'static revoke must remove inbox B\'s only installation');
    print('R2 PASS: staticRevokeInstallations honored the target inboxId '
        'and the signer key');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
