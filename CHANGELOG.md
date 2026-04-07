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
