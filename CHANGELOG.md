## 1.1.0

### BREAKING: `sendMessageByInboxId` now returns `{messageId, topic}`

The return type changed from `Future<String?>` (the message id) to `Future<Map<String, dynamic>?>` with two keys: `messageId` and `topic`. `topic` is the live DM conversation the message was actually sent to — the send path is find-or-create, so this is always the canonical DM topic. Callers use it to heal a stale cached conversation topic (libxmtp can stitch duplicate DMs, after which a previously-cached topic no longer matches the surviving conversation).

Implemented on all four platforms. iOS returns the topic natively from the send; Android, Windows, and Web resolve it via the same `findOrCreateDM` lookup the send used (idempotent and local after the first call). The lookup is best-effort: on failure `topic` is `null` and the send still succeeds — callers must treat `topic` as optional.

Migration: `final id = await sendMessageByInboxId(...)` becomes `final result = await sendMessageByInboxId(...); final id = result?['messageId'] as String?;`.

### Encrypted archive backups: `exportArchive` / `importArchive` / `archiveMetadata`

Native libxmtp encrypted archives (the `xmtp_archive` export/import primitives over the MLS store), surfaced as three new methods on `XmtpPlugin`:

* **`exportArchive(path, password, {elements, startNs, endNs, excludeDisappearing})`** — write an encrypted archive of the active inbox's data to `path` (e.g. a `.xmtpBak` file). `elements` selects `BackupElement.messages` and/or `BackupElement.consent`; an empty list archives both (the upstream default). Optional `startNs`/`endNs` bound the time range.

* **`importArchive(path, password)`** — decrypt and import an archive into the active inbox's MLS store. The import is additive. A wrong password — or an archive made by a different inbox — fails to decrypt before anything is written.

* **`archiveMetadata(path, password)`** — read the archive header (`ArchiveMetadata`: backup version, elements, exported-at, time range) without importing. Doubles as a password check, since a wrong key fails the open.

**Key derivation happens once, in Dart, and is pinned.** The 32-byte encryption key is `Argon2id(password, salt = inboxId)` via pointycastle (version 0x13, 19456 KiB memory, 2 iterations, 1 lane). Because the KDF runs in pure Dart, Android/iOS/Windows produce a byte-identical key — an archive made on one platform restores on any other device of the same inbox. The password never crosses the platform boundary; the native layers only ever see the derived key. These parameters must never change or existing backups stop decrypting. The KDF is also exported as a public `deriveArchiveKey(password, inboxId)` for consumers that need the raw key.

Platform coverage: Android, iOS, and Windows (new Rust bridge module `rust/src/api/archive.rs`, mirroring `bindings_ffi/src/mls.rs::{create_archive, import_archive, archive_metadata}` @ libxmtp v1.9.0). Web throws `UnimplementedError`.

### New codec: Wallet Send Calls (`xmtp.org/walletSendCalls:1.0`, XIP-59 / EIP-5792)

`WalletSendCallsCodec` plus the `WalletSendCalls` / `WalletCall` / `WalletCallMetadata` content classes, registered in the default codec registry. This is the actionable "invoice" side of in-chat payments: the sender proposes EIP-5792 `wallet_sendCalls` (version, chainId, from, calls with to/data/value/gas + per-call metadata, optional capabilities); the recipient reviews, signs, and broadcasts, then replies with a `TransactionReference` receipt.

Encode emits the canonical flat JSON shape from libxmtp `crates/xmtp_content_types/src/wallet_send_calls.rs`, so sends interoperate with libxmtp / xmtp-js / Base. Decode is lenient: every field optional, and extra metadata keys (serde-flattened siblings on the wire) are preserved in `WalletCallMetadata.extra`.

### `TransactionReference` codec hardened for cross-client receive (XIP-21)

Real-world senders (e.g. Base payment agents) have been observed emitting the payload **wrapped** under a `"transactionReference"` key and with **partial** metadata, where the canonical libxmtp shape is a flat object with all six metadata fields. Decode now follows Postel's law: unwraps the envelope if present, accepts `networkId` as string-or-number, treats every metadata field as optional, and preserves unknown metadata keys in `TransactionMetadata.extra` instead of dropping them. Encode is unchanged — canonical flat, only set fields emitted.

Source-breaking detail for consumers: `TransactionMetadata`'s fields are now nullable (previously all `required`). Covered by new unit tests in `test/transaction_codecs_test.dart`.

### Fix: `staticDeleteLocalDatabase` now honors the custom `dbDirectory`

`staticDeleteLocalDatabase` gained an optional `dbDirectory` parameter that mirrors the one on `initializeClient`. On iOS the previous implementation always deleted from the app's Documents directory, but XMTPiOS stores the encrypted `xmtp-<env>-<inboxId>.db3` under whatever `dbDirectory` the client was opened with. Consumers that share the installation DB with a Notification Service Extension via an App Group container were therefore deleting a file that did not exist while the real DB survived — so a DB-key-mismatch recovery ("erase & continue") silently failed and the next `initializeClient` hit the same mismatch.

The iOS implementation now:
* deletes from `dbDirectory ?? Documents` so it matches the create-time path;
* removes the **legacy alias** (`xmtp-<legacyEnv>-<inboxId>.db3`) XMTPiOS falls back to reading, not just the current one;
* cleans up SQLite sidecars with the correct hyphenated `-wal` / `-shm` names (older builds used `.wal` / `.shm`, leaking the journals).

Callers that pass a `dbDirectory` to `initializeClient` MUST pass the same value here. Android (DB always under the app files dir) and Web/Windows ignore the new parameter; the change is fully backward-compatible.

## 1.0.6

### Push notifications surface

Five new APIs that wire `xmtp_plugin` consumers to an `xmtp/example-notification-server-go`-compatible push notification stack across Android, iOS, and Windows. Web throws `UnimplementedError` (FCM web-push is out of scope — service-worker integration is a wildly different shape than the Flutter `firebase_messaging` path; revisit if/when a consumer needs it).

* **`Future<List<PushHmacKeyEntry>> getAllHmacKeys()`** — aggregate HMAC keys for every conversation, including stitched duplicate DMs. libxmtp returns three keys per conversation (prior / current / next 30-day epoch) so push delivery keeps matching across epoch boundaries without re-subscribing.

* **`Future<String> getWelcomeTopic()`** — this installation's per-installation welcome topic. Format `/xmtp/mls/1/w-${installationId}/proto`. Required to receive push for brand-new conversations from previously-unknown senders (the welcome envelope arrives on this topic before any per-conversation topic exists).

* **`Future<List<PushSubscription>> getAllPushTopics()`** — convenience composition over `getAllHmacKeys()` + `getWelcomeTopic()`. Returns one `PushSubscription` per conversation topic (with all three HMAC keys attached) plus one entry for the welcome topic (with empty HMAC list). This is the exact shape the notification server's `subscribeWithMetadata` endpoint expects.

* **`Future<List<Map<String, dynamic>>> processPushMessage(String topic, Uint8List encryptedBytes)`** — decrypt an FCM/APNs push payload for an existing conversation. `topic` is in full XMTP wire format (the value the push payload's `topic` field carries). Returns 0 or 1 messages (libxmtp may surface multiple from a single envelope on Rust path; Android/iOS bindings collapse to a single optional).

* **`Future<List<Map<String, dynamic>>> processWelcome(Uint8List encryptedBytes)`** — decrypt an FCM/APNs push payload that arrived on the welcome topic. Creates the new conversation locally and returns its info. Returns 1 entry on Android/iOS; Rust path may return more from DM-stitching welcomes.

### Topic format convention

Push APIs deal in the **full XMTP wire topic format** (`/xmtp/mls/1/g-${hex}/proto`, `/xmtp/mls/1/w-${id}/proto`) end-to-end, because that is what both the notification server and FCM/APNs push payloads use. This intentionally diverges from the rest of the plugin's Rust API surface (raw hex group_ids), and matches what the official `xmtp-android` and `xmtp-ios` push examples do.

### Internal: Rust bridge module

New `rust/src/api/push.rs` exposes three libxmtp methods via flutter_rust_bridge: `get_all_hmac_keys()` (flattens libxmtp's `HashMap<group_id, Vec<HmacKey>>` into `Vec<HmacKeyEntry>`), `process_push_message(topic, bytes)` (calls `group.process_streamed_group_message`), `process_welcome(bytes)` (calls `client.process_streamed_welcome_message`). Includes `format_group_topic` / `parse_group_topic` topic-format helpers with unit tests.

### Internal: `ConversationInfo` map now includes `conversationType`

The Windows path's `_conversationInfoToMap` now includes the always-populated `conversationType` field (`"dm"` or `"group"`) from the Rust `ConversationInfo` struct. Pre-existing gap, surfaced while wiring `processWelcome`'s result through the same helper. Android + iOS already returned this field via their native listGroups / listDms paths; Windows was the outlier.

## 1.0.5

### Cross-client interoperability for `RemoteStaticAttachment`

* **Added `RemoteAttachmentCodec.encodeEncrypted<T>(content, codec, {filename})`.** New public static helper that produces the canonical XMTP RemoteStaticAttachment wire shape: it calls `codec.encode(content)`, wraps the result in an `EncodedContent` protobuf with the codec's `ContentTypeId`, serializes the envelope, then AES-256-GCM encrypts the serialized bytes with a fresh random secret / salt / nonce (HKDF-SHA256-derived key, matching the existing `_decrypt` shape). Returns an `EncryptedEncodedContent` with the ciphertext, key material, SHA-256 content digest, and optional filename — exactly what callers need to upload + reference from a `RemoteAttachmentContent` envelope. API mirrors `xmtp-android` `RemoteAttachmentCodec.encodeEncrypted<T>(content, codec)`, `xmtp-ios` `RemoteAttachment.encodeEncrypted<Codec, T>(content:, codec:)`, and `xmtp-js` `RemoteAttachmentCodec.encodeEncrypted<T>(content, codec)`.

* **Why this matters — receive interop with all spec-compliant XMTP clients.** Pre-1.0.5 there was no public encrypt-side helper here, so any downstream consumer writing their own send path had to AES-GCM-encrypt the raw inner payload directly. That decrypted into bare bytes on the receiver, not into a protobuf, and every spec-compliant XMTP receiver throws on parse with no fallback:
  - **xmtp-android** `RemoteAttachmentCodec.kt:84` — `return EncodedContent.parseFrom(decrypted)` → `InvalidProtocolBufferException`, propagates up `RemoteAttachment.load<T>()`.
  - **xmtp-ios** `RemoteAttachmentCodec.swift:155` — `return try EncodedContent(serializedData: decrypted)` → throws, propagates up `content()`.
  - **xmtp-js** `RemoteAttachment.ts:90-101` — `proto.EncodedContent.decode(...)` throws on bad protobuf, then `if (!encodedContent.type) throw`, then `if (!codec) throw "no codec found"`.

  Net effect of the bug: any chat between an app using the pre-1.0.5 plugin's hand-rolled send path and a native xmtp-ios / xmtp-android / xmtp-js client would render the codec's `fallback()` string ("Can't display "<filename>". This app doesn't support attachments.") for every image / video / file sent from the plugin side, even though the envelope, key material, and digest were all valid. Upgrading to 1.0.5 and routing send paths through `encodeEncrypted` produces a wire shape byte-identical to the native SDKs and unlocks cross-client interop.

* **Receive path unchanged.** `_fetchDecryptAndParse` already tried `EncodedContent.fromBuffer(decrypted)` first (the standard path) and only fell back to filename-extension MIME inference when that parse failed. After this release, plugin users who route sends through `encodeEncrypted` will always hit the standard path; older history (raw-bytes payloads from pre-1.0.5 senders) continues to render via the fallback.

### Receive-side fallback MIME ladder for video extensions

* **Expanded the silent-fallback MIME inference in `_fetchDecryptAndParse`** to recognize `.webp`, `.heic`, `.heif`, `.mp4`, `.mov`, `.webm`, `.m4v` in addition to the pre-existing `.png` / `.jpg` / `.jpeg` / `.gif` / `.pdf`. Filename matching is now case-insensitive (catches iOS-style `.MOV`). Unknown extensions still fall through to `application/octet-stream`.

* **Why this matters even with `encodeEncrypted` shipped.** The fallback only fires when the protobuf parse fails — which after this release shouldn't happen for spec-compliant senders. But two scenarios still hit it: (1) old chat-history messages encrypted under the pre-1.0.5 raw-bytes shape, and (2) any non-conforming sender (custom codec, bug). Without this expansion, video filenames in those scenarios fell to `octet-stream` and downstream UI rendered them as generic file attachments instead of video players.

### Migration

Plugin users with their own send paths should replace any custom "encrypt raw bytes for remote attachment" logic with a call to `RemoteAttachmentCodec.encodeEncrypted(content, codec)`. If you were previously encrypting raw `Uint8List` directly, wrap it in an `AttachmentContent(data, mimeType, filename)` and pass `AttachmentCodec()` as the codec.

```dart
// Before — produced spec-incompatible payloads:
// final cipher = ... AES-GCM over fileBytes directly ...

// After:
final encrypted = await RemoteAttachmentCodec.encodeEncrypted(
  AttachmentContent(data: fileBytes, mimeType: mime, filename: name),
  AttachmentCodec(),
  filename: name,
);
// upload encrypted.payload, then wire encrypted.{contentDigest, secret, salt, nonce}
// into your RemoteAttachmentContent envelope.
```

## 1.0.4

* **Added `staticGetInboxIdForAddress(address, environment)`** — Network lookup for the real XMTP inbox ID mapped to an Ethereum address. Handles linked accounts (keys added to another inbox via `addAccount`). Does NOT require an initialized client. Available on Android, iOS, and Windows.
* **Added `staticDeleteLocalDatabase(address, inboxId, environment)`** — Deletes the local XMTP database files for a given address/inboxId without requiring an initialized client. Enables recovery when the DB encryption key is lost but the local DB still exists. Available on Android, iOS, and Windows.
* **Removed `computeInboxId`** — Gave wrong results for addresses added to a different inbox via `addAccount`. Use `staticGetInboxIdForAddress` (network lookup) instead.

## 1.0.3

* **Web: Upgraded to XMTP Browser SDK v6.** Complete rewrite of the JavaScript bridge (`web/xmtp_client_manager.js`). All v6 API changes adopted: `createDm`/`createGroup` (renamed), `sendText` (replaces `send`), `IdentifierKind` enums, `accountIdentifiers` (replaces `addresses`), `fetchInboxState`/`inboxState` split, `ConsentState`/`ConsentEntityType` enums.
* **Web: Switched to Vite bundler** for proper Web Worker and WASM handling. Includes `vite.config.js` and build instructions.
* **Web: Added viem** for proper secp256k1 ECDSA message signing (replaces SHA-256 mock signer).
* **Web: Fixed client.close()** — previous versions leaked Web Workers on re-initialization, blocking OPFS database access for new clients.
* **Web: Fixed InboxState field mapping** — `accountIdentifiers` (not `identifiers`), `recoveryIdentifier` (not `recoveryIdentity`), `IdentifierKind` enum conversion.
* **Web: Fixed listGroupMembers** — updated from `m.addresses` (v5) to `m.accountIdentifiers` (v6).
* **Cross-platform: Conditional export** of `XmtpPluginWindows` using `dart.library.js_interop` guard. Web gets a no-op stub, native platforms get the real FFI implementation. Fixes dart2js compilation failure when building for web.
* **Cross-platform: Defensive encodedContent type handling** — `List<dynamic>` (from JS interop) is now converted to `Uint8List` in both `_processMessages` and `subscribeToAllMessages`. No behavior change on native platforms.
* **Test app now runs on all platforms** — Web, Windows, and Android from a single `test_app/`. 22 integration tests covering key generation, client init, DMs, groups, sync, addAccount, and inbox state verification.

## 1.0.2

* Clarified Windows setup: DLL is not included in pub.dev package, clone repo + build + copy workflow documented
* Updated README and START_HERE with explicit per-platform instructions

## 1.0.1

* Removed untested macOS and Linux platform declarations
* Fixed lint warnings (unused imports, missing @override annotations, unnecessary type checks)
* Added .gitignore, removed generated files from tracking

## 1.0.0

* Initial release
* Client initialization with private key and encrypted local database
* Direct messages (DMs) and group conversations
* Real time message streaming via `subscribeToAllMessages()`
* Extensible codec system with built in support for text, attachments, remote attachments, reactions, replies, read receipts, actions, intents, group updates, delete messages, leave requests, and multi remote attachments
* Consent management per conversation and per inbox
* Group operations: create, update metadata, manage members and admin roles
* Inbox management: installations, account linking, recovery identity
* History sync across devices
* Platform support: Android (xmtp-android SDK), iOS (XMTP Swift SDK), Windows (Rust FFI via libxmtp), Web (XMTP Browser SDK v5)
