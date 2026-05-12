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
