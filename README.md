# xmtp_plugin

A Flutter plugin for [XMTP](https://xmtp.org) decentralized messaging. Send and receive messages, manage group conversations, handle consent, and stream incoming messages in real time across Android, iOS, Windows, and Web from a single Dart API.

## Platform Architecture

Each platform connects to the XMTP network through its own native implementation, giving you full protocol support everywhere Flutter runs.

| Platform | Backend | Transport |
|----------|---------|-----------|
| Android | [xmtp-android](https://github.com/xmtp/xmtp-android) SDK | Method Channel |
| iOS | [xmtp-ios](https://github.com/xmtp/xmtp-ios) Swift SDK | Method Channel |
| Windows | [libxmtp](https://github.com/xmtp/libxmtp) via Rust FFI | flutter_rust_bridge |
| Web | [XMTP Browser SDK v6](https://github.com/xmtp/xmtp-js) | JavaScript Interop |

On Android and iOS, Dart talks to the official XMTP native SDKs over a standard Flutter method channel. The native SDKs handle client creation, MLS group encryption, message encoding, and gRPC communication with the XMTP network.

On Windows, there is no official XMTP SDK for the platform. Instead, this plugin includes a Rust crate (`rust/`) that wraps `libxmtp` directly and exposes it to Dart through [flutter_rust_bridge](https://github.com/aspect-build/flutter_rust_bridge). The Rust code compiles to a native DLL via [Corrosion](https://github.com/aspect-build/corrosion) (integrated in the Windows CMakeLists.txt), and Dart calls into it using FFI. This bypasses the C++ method channel entirely: Dart calls Rust functions directly, Rust talks to libxmtp, and libxmtp handles the protocol. The bridge code is auto-generated from the Rust API modules by running `flutter_rust_bridge_codegen generate`.

On Web, Dart uses `dart:js_interop` to call a JavaScript facade (`web/xmtp_client_manager.js`) that wraps the XMTP Browser SDK v6. The Browser SDK runs XMTP's WASM bindings inside a Web Worker, with SQLite persistence via the browser's Origin Private File System (OPFS).

All four platform implementations conform to the same `XmtpPluginPlatform` interface, so your application code is identical regardless of where it runs.

## Features

**Messaging**
Sending and receiving direct messages and group messages. Text, attachments, remote attachments (encrypted file URLs with download metadata), reactions, replies, read receipts, and custom content types through an extensible codec system.

**Group Conversations**
Creating groups, adding and removing members, promoting and demoting admins and super admins, updating group metadata (name, description, image), and querying member roles.

**Consent Management**
Per conversation and per inbox consent states. Allow, deny, or check consent before delivering messages. Sync consent preferences across installations.

**Real Time Streaming**
`subscribeToAllMessages()` returns a Dart `Stream` of incoming messages across all conversations, decoded through the codec registry automatically.

**Inbox and Identity**
Multi installation support with history sync across devices. Add or remove Ethereum accounts from an inbox, revoke installations, query inbox state, and change recovery identifiers.

**Content Codecs**
A registry based codec system with 13 built in codecs and support for registering your own.

| Codec | Content Type | Description |
|-------|-------------|-------------|
| TextCodec | xmtp.org/text | Plain UTF 8 text messages |
| AttachmentCodec | xmtp.org/attachment | File attachments with filename and MIME type |
| RemoteAttachmentCodec | xmtp.org/remoteStaticAttachment | Encrypted files hosted remotely with download params |
| MultiRemoteAttachmentCodec | xmtp.org/multiRemoteStaticContent | Multiple remote attachments in a single message |
| ReplyCodec | xmtp.org/reply | Replies referencing a parent message |
| ReactionV2Codec | xmtp.org/reaction | Emoji reactions on messages |
| ReadReceiptCodec | xmtp.org/readReceipt | Read receipt signals |
| DeleteMessageCodec | xmtp.org/deleteMessage | Soft delete markers |
| LeaveRequestCodec | xmtp.org/leaveRequest | Group leave signals |
| GroupUpdatedCodec | xmtp.org/group_updated | Group metadata change events |
| TransactionReferenceCodec | xmtp.org/transactionReference | On chain transaction references |
| ActionsCodec | coinbase.com/actions | Interactive action menus (bot messaging) |
| IntentCodec | coinbase.com/intent | User responses to action menus |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  xmtp_plugin: ^1.0.3
```

### Android

Add the XMTP Android SDK dependency. The plugin's `android/build.gradle` already includes it, but your app needs internet permission in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Minimum SDK: 21. Requires NDK 27.0.12077973 — set `ndkVersion = "27.0.12077973"` in your app's `android/app/build.gradle.kts`.

### iOS

The plugin depends on the XMTP Swift SDK via CocoaPods (`XMTP ~> 4.0`). Run `pod install` in your ios/ directory. Minimum iOS 14.0.

### Windows

Windows support requires a native DLL (`xmtp_plugin_native.dll`) built from the Rust crate in this repository. The pub.dev package includes the Dart FFI bindings but **not** the pre-built DLL — you need to clone the repo and build it yourself.

**Step 1: Clone the repository**

```powershell
git clone https://github.com/0xjmsl/xmtp_plugin.git
```

**Step 2: Install build requirements**

1. Rust toolchain (`rustup` with stable channel)
2. Visual Studio with C++ build tools and ATL headers (Individual Components: "C++ ATL for latest v143 build tools")
3. CMake 3.14+
4. Strawberry Perl (required by some Rust crypto dependencies)

**Step 3: Build the DLL**

```powershell
cd xmtp_plugin/rust
powershell -ExecutionPolicy Bypass -File build.ps1
```

First build takes 6+ minutes (500+ crates). Subsequent builds are fast. This outputs `rust/target/debug/xmtp_plugin_native.dll` (~58MB debug).

**Step 4: Copy the DLL next to your app executable**

```powershell
# For debug builds (flutter run)
Copy-Item 'xmtp_plugin/rust/target/debug/xmtp_plugin_native.dll' '<your_app>/build/windows/x64/runner/Debug/'

# For release builds (flutter build windows)
Copy-Item 'xmtp_plugin/rust/target/release/xmtp_plugin_native.dll' '<your_app>/build/windows/x64/runner/Release/'
```

If the DLL is missing, the app crashes on launch with no clear error. If the DLL is <1MB it's a stale stub — rebuild with `cargo build`.

**Important:** Kill any running instance of your app before rebuilding. The linker cannot overwrite the exe while the process is running (LNK1168 error).

**Debug vs Release:** The DLL build mode must match the app build mode. A Debug DLL won't work with a Release app and vice versa. Use `cargo build` for debug, `cargo build --release` for release. The outputs are in `rust/target/debug/` and `rust/target/release/` respectively.

**flutter_rust_bridge version:** Both Dart and Rust sides are pinned to `2.11.1`. Use `flutter_rust_bridge: 2.11.1` (no caret) in your app's pubspec.yaml. A version mismatch causes a "codegen version mismatch" crash at runtime.

**Why no pre-built DLL on pub.dev?** The Rust crate depends on `libxmtp` which links against platform-specific C libraries (OpenSSL, etc.) during compilation. Cross-compiling and shipping a universal pre-built binary is not practical — the build must happen on the target machine with its own toolchain. The CMakeLists.txt uses Corrosion to automate this when the Rust source is available (local path dependency), but pub.dev does not include the `rust/` directory.

### Web

Web requires building the JavaScript bundle from the plugin's `web/` directory and placing it in your app's `web/` folder.

**Step 1: Build the bundle**

```bash
cd <path-to-xmtp_plugin>/web
npm install
npx vite build
```

This produces a `dist/` folder containing the bundle (~163KB JS), Web Worker scripts, and the XMTP WASM binary (~11MB).

**Step 2: Copy to your app**

```bash
cp -r dist/ <your_app>/web/xmtp/
```

**Step 3: Add the script tag** in your `web/index.html` before the Flutter bootstrap:

```html
<script type="module" src="xmtp/xmtp_bundle.js"></script>
```

**Web limitations:**

- **No persistent key storage.** OPFS databases survive page reloads but are tied to the browser origin. Private browsing, clearing site data, or switching browsers loses all state. Your app must handle key backup/restore.
- **Single tab only.** The XMTP WASM bindings use OPFS with a SyncAccessHandle Pool VFS that does not support multiple simultaneous connections. Running your app in multiple tabs will cause database errors.
- **One client at a time.** Re-initializing with a different key properly closes the previous client (terminates the Web Worker and releases OPFS handles). But you cannot run two XMTP clients simultaneously.
- **Group names via `newGroup` options** may appear blank due to a Dart `jsify()` interop limitation with nested Maps. Group functionality works correctly otherwise.

## Quick Start

```dart
import 'package:xmtp_plugin/xmtp_plugin.dart';
import 'package:xmtp_plugin/codecs.dart';

final xmtp = XmtpPlugin();

// Generate a new private key (or load an existing one)
final privateKey = await xmtp.generatePrivateKey();

// Generate a database encryption key (32 bytes, persist this securely)
final dbKey = Uint8List(32); // use SecureRandom in production

// Initialize the XMTP client (connects to production by default)
final address = await xmtp.initializeClient(privateKey, dbKey);
print('Connected as $address');
```

## Network Environment

The plugin connects to the XMTP production network by default. You can target the dev or local network by passing the `environment` parameter to `initializeClient`. Omitting it or passing any unrecognized value defaults to production, so existing code requires no changes.

```dart
// Production (default, can be omitted)
await xmtp.initializeClient(privateKey, dbKey);

// Dev/test network
await xmtp.initializeClient(privateKey, dbKey, environment: 'dev');

// Local node (localhost:5556)
await xmtp.initializeClient(privateKey, dbKey, environment: 'local');
```

| Environment | gRPC Host | History Sync |
|-------------|-----------|--------------|
| `production` | grpc.production.xmtp.network | message-history.production.ephemera.network |
| `dev` | grpc.dev.xmtp.network | message-history.dev.ephemera.network |
| `local` | localhost:5556 | localhost:5558 |

Once initialized, all operations (messaging, groups, consent, sync) use the selected environment automatically.

**Note on static methods:** `XmtpPlugin.staticRevokeInstallations` and `XmtpPlugin.staticInboxStatesForInboxIds` operate without an active client. On Android and iOS they always connect to the production network. On Windows and Web, if a client has been initialized in the current session they inherit its environment, otherwise they also default to production.

## Sending Messages

```dart
// Send a text message to an Ethereum address
await xmtp.sendMessage(
  '0xRecipientAddress',
  'Hello from Flutter!',
  'xmtp.org',
  'text',
);

// Send a text message by inbox ID (for existing conversations)
await xmtp.sendMessageByInboxId(
  recipientInboxId,
  'Hello again!',
  'xmtp.org',
  'text',
);
```

## Streaming Messages

```dart
// Listen to all incoming messages in real time
xmtp.subscribeToAllMessages().listen((message) {
  final senderInboxId = message['senderInboxId'];
  final topic = message['conversationTopic'];
  final decoded = message['decodedContent'];

  print('New message from $senderInboxId in $topic');

  if (decoded is String) {
    print('Text: $decoded');
  } else if (decoded is AttachmentContent) {
    print('File: ${decoded.filename} (${decoded.mimeType})');
  }
});
```

Messages are automatically decoded through the codec registry. The `decodedContent` field contains the typed Dart object for the content type (a `String` for text, an `AttachmentContent` for attachments, etc.).

## Conversations

```dart
// List all conversations (DMs and groups)
final conversations = await xmtp.listConversations();

// List only DMs, optionally filtered by consent state
final dms = await xmtp.listDms(consentState: 'allowed');

// List only groups
final groups = await xmtp.listGroups(consentState: 'allowed');

// Find or create a DM with someone by their inbox ID
final dm = await xmtp.findOrCreateDMWithInboxId(theirInboxId);

// Check if an address is reachable on XMTP
final canReach = await xmtp.canMessageByAddress('0xSomeAddress');

// Look up an inbox ID from an Ethereum address
final inboxId = await xmtp.inboxIdFromAddress('0xSomeAddress');

// Retrieve messages after a given date
final messages = await xmtp.getMessagesAfterDate(
  '0xPeerAddress',
  DateTime.now().subtract(Duration(days: 7)),
);
```

## Group Conversations

```dart
// Create a group with specific members
final group = await xmtp.newGroup(
  ['inboxId1', 'inboxId2'],
  {'name': 'Project Chat', 'description': 'Coordination'},
);
final topic = group['topic'];

// Send a message to the group
await xmtp.sendGroupMessage(topic, 'Hey team!', 'xmtp.org', 'text');

// Manage members
await xmtp.addGroupMembers(topic, ['newMemberInboxId']);
await xmtp.removeGroupMembers(topic, ['departingInboxId']);

// Admin operations
await xmtp.addGroupAdmin(topic, 'inboxId');
await xmtp.removeGroupAdmin(topic, 'inboxId');
await xmtp.addGroupSuperAdmin(topic, 'inboxId');

// Update group metadata
await xmtp.updateGroup(topic, {
  'name': 'New Name',
  'description': 'Updated description',
  'imageUrl': 'https://example.com/avatar.png',
});

// Check a member's role
final role = await xmtp.getGroupMemberRole(topic, someInboxId);
print('isAdmin: ${role['isAdmin']}, isSuperAdmin: ${role['isSuperAdmin']}');
```

## Consent Management

```dart
// Check and set conversation consent
final state = await xmtp.getConversationConsentState(topic);
await xmtp.setConversationConsentState(topic, 'allowed'); // or 'denied'

// Check and set inbox level consent
final inboxState = await xmtp.getInboxConsentState(inboxId);
await xmtp.setInboxConsentState(inboxId, 'allowed');

// Sync consent preferences across all installations
await xmtp.syncConsentPreferences();
```

## Custom Codecs

Register your own content types by extending `XMTPCodec`:

```dart
class LocationCodec extends XMTPCodec {
  @override String get authorityId => 'com.myapp';
  @override String get typeId => 'location';
  @override int get versionMajor => 1;
  @override int get versionMinor => 0;

  @override
  Future<Map<String, dynamic>> encode(dynamic content) async {
    final loc = content as Map<String, double>;
    final bytes = utf8.encode(jsonEncode(loc));
    return {
      'content': Uint8List.fromList(bytes),
      'parameters': <String, String>{},
    };
  }

  @override
  Future<dynamic> decode(EncodedContent encodedContent) async {
    return jsonDecode(utf8.decode(encodedContent.content));
  }
}

// Register before sending
xmtp.registerCodec(LocationCodec());

// Send a location
await xmtp.sendMessage(
  recipientAddress,
  {'lat': 40.7128, 'lng': -74.0060},
  'com.myapp',
  'location',
);
```

## Attachments and Remote Attachments

```dart
// Register attachment codecs
xmtp.registerCodec(AttachmentCodec());
xmtp.registerCodec(RemoteAttachmentCodec());

// Load a remote attachment from an encrypted URL
final attachment = await xmtp.loadRemoteAttachment(
  url: remoteUrl,
  contentDigest: digest,
  secret: secretBytes,
  salt: saltBytes,
  nonce: nonceBytes,
  scheme: 'https',
  contentLength: fileSize,
  filename: 'photo.jpg',
);
print('Downloaded ${attachment.filename} (${attachment.mimeType})');
```

## Sync and History

```dart
// Sync all conversations from the network
final result = await xmtp.syncAll(consentStates: ['allowed']);
print('Synced ${result['numGroupsSynced']} conversations');

// Sync a single conversation
await xmtp.syncConversation(topic);

// Request history sync from other installations (cross device)
await xmtp.sendSyncRequest();
```

## Inbox Management

```dart
// Get current installation ID
final installationId = await xmtp.getInstallationId();

// Query inbox state (identities, installations, recovery)
final state = await xmtp.inboxState(refreshFromNetwork: true);
print('Inbox: ${state['inboxId']}');
print('Identities: ${state['identities']}');
print('Installations: ${state['installations']}');

// Revoke a specific installation
await xmtp.revokeInstallations(signerKey, ['installationIdToRevoke']);

// Revoke all other installations (keep only current)
await xmtp.revokeAllOtherInstallations(signerKey);

// Link another Ethereum account to this inbox
await xmtp.addAccount(newAccountPrivateKey);

// Remove an account from this inbox
await xmtp.removeAccount(recoveryKey, '0xAddressToRemove');

// Change the recovery identifier
await xmtp.changeRecoveryIdentifier(signerKey, '0xNewRecoveryAddress');

// Static operations (no active client needed)
await XmtpPlugin.staticRevokeInstallations(
  signerPrivateKey: key,
  inboxId: targetInboxId,
  installationIds: ['id1', 'id2'],
);
```

## Project Structure

```
lib/
  xmtp_plugin.dart                  Main plugin API (XmtpPlugin class)
  xmtp_plugin_platform_interface.dart   Platform abstraction
  xmtp_plugin_method_channel.dart       Android/iOS method channel impl
  xmtp_plugin_windows.dart              Windows Rust FFI impl
  xmtp_plugin_web.dart                  Web JavaScript interop impl
  codecs.dart                           Codec registry + 13 built in codecs
  generated/                            Protobuf generated message classes
  src/rust/                             Auto generated Rust FFI bindings

android/    Kotlin plugin (wraps xmtp-android SDK)
ios/        Swift plugin (wraps XMTP iOS SDK)
windows/    CMake config (builds Rust crate via Corrosion)
web/        JavaScript bridge to XMTP Browser SDK v6 (Vite build)
rust/       Rust FFI crate wrapping libxmtp (Windows)
proto/      Protobuf definitions for custom content types
```

## Requirements

| Platform | Minimum | SDK/Runtime |
|----------|---------|-------------|
| Android | API 21 | xmtp-android 4.7.0 |
| iOS | 14.0 | XMTP Swift 4.0 |
| Windows | 10+ | Rust stable, CMake 3.14 |
| Web | Modern browsers (OPFS support) | XMTP Browser SDK 6.x |
| Flutter | 3.3.0+ | Dart SDK 3.5.4+ |

## Test App

The [GitHub repository](https://github.com/0xjmsl/xmtp_plugin) includes a `test_app/` directory with a Flutter integration test suite that runs 22 steps against the XMTP dev network. The same test app runs on **Web, Windows, and Android** from a single codebase.

```bash
# Web
flutter run -d chrome

# Windows (requires DLL, see Windows setup above)
flutter run -d windows

# Android
flutter run -d <device>
```

For **Windows**, the DLL must be in the Debug runner directory. After building the Rust crate:

```powershell
Copy-Item '..\rust\target\debug\xmtp_plugin_native.dll' 'build\windows\x64\runner\Debug\'
```

For **Web**, the XMTP bundle must be built and copied first (see Web setup above).

The suite creates ephemeral keys for three accounts (Alice, Bob, Charlie), registers them on the dev network, and tests: DMs, group creation with metadata, message sending and receiving across accounts, conversation sync and discovery, addAccount identity linking, inbox state verification, and shared inbox confirmation. Results are written to a log file on native platforms.

## Known Limitations

**History sync** across installations (e.g. syncing conversations from one device to another via `sendSyncRequest`) is not reliable. The `sendSyncRequest` and `syncAll` APIs are available but conversation transfer may not complete. Do not depend on cross-installation sync for critical flows.

**One client at a time.** The plugin uses a singleton client internally. Initializing a new client replaces the previous one. To switch between accounts, call `initializeClient` again with different keys.

**Web: No persistent key storage.** Browser databases (OPFS) persist across page reloads within the same origin, but clearing site data, private browsing, or switching browsers loses all state. Your app is responsible for key backup and restore.

**Web: Single tab restriction.** The XMTP WASM bindings use OPFS with a VFS that does not support multiple simultaneous connections. Multiple tabs accessing the same app will cause database errors.

**Web: Database encryption key must match per inbox.** When re-initializing a client for the same inbox (e.g., after `addAccount`), use the same `dbKey`. A mismatched key causes a SQLCipher error. This applies to all platforms but is especially relevant on web where OPFS databases persist.

## License

MIT
