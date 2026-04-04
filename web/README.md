# XMTP Flutter Web Implementation

This directory contains the complete web implementation for the XMTP Flutter plugin using the official XMTP Browser SDK.

## Files Overview

- **`package.json`** - NPM dependencies for XMTP browser SDK
- **`xmtp_client_manager.js`** - Comprehensive XMTP client implementation
- **`index.html`** - Basic HTML template for loading the client manager
- **`example.html`** - Interactive demo of all XMTP functionality
- **`node_modules/`** - Installed XMTP browser SDK dependencies

## Features Implemented

### ✅ Core Client Operations
- Private key generation
- Client initialization with private keys
- Address and inbox ID management

### ✅ Messaging
- Send messages to addresses
- Send messages by inbox ID
- Send group messages
- Real-time message streaming
- Message history retrieval

### ✅ Conversations
- List all conversations
- List DMs and groups separately
- Accept/deny conversations
- Find or create DM conversations

### ✅ Group Management
- Create new groups
- List group members, admins, super admins
- Add/remove group members
- Add/remove group admins and super admins
- Update group metadata
- Get group member roles

### ✅ Content Types & Codecs
- Text messages
- Attachment support
- Remote attachment loading
- Extensible codec registry

## Setup Instructions

1. **Install Dependencies**
   ```bash
   cd web
   npm install
   ```

2. **Build for Production** (optional)
   ```bash
   npm run build
   ```

3. **Serve the Files**
   Use any web server to serve the files. For example:
   ```bash
   # Using Python
   python -m http.server 8000

   # Using Node.js http-server
   npx http-server

   # Using Flutter web server
   flutter run -d web-server --web-port 8080
   ```

## Usage in Flutter Web

The web implementation automatically registers itself when the Flutter web app loads. The JavaScript files need to be included in your Flutter web project.

### Integration Steps

1. **Copy Web Files**: Copy the contents of this `web/` directory to your Flutter project's `web/` directory.

2. **Update index.html**: Add the XMTP client manager to your Flutter web app's `index.html`:
   ```html
   <script type="module" src="./xmtp_client_manager.js"></script>
   ```

3. **Use the Plugin**: Use the XMTP Flutter plugin normally in your Dart code:
   ```dart
   import 'package:xmtp_plugin/xmtp_plugin.dart';

   final xmtp = XmtpPlugin();

   // Generate private key
   final privateKey = await xmtp.generatePrivateKey();

   // Initialize client
   final address = await xmtp.initializeClient(privateKey, dbKey);

   // Send message
   await xmtp.sendMessage(recipientAddress, content, 'xmtp.org', 'text', '1');
   ```

## Demo Usage

Open `example.html` in a web browser to see an interactive demo of all features:

1. **Generate Private Key** - Creates a new private key for the client
2. **Initialize Client** - Sets up the XMTP client with the private key
3. **Send Messages** - Send text messages to other XMTP users
4. **Subscribe to Messages** - Receive real-time messages
5. **Manage Conversations** - List and manage DMs and groups
6. **Create Groups** - Create new group conversations

## Architecture

```
Flutter Web App
       ↓
xmtp_plugin_web.dart (Dart)
       ↓
JavaScript Interop (dart:js)
       ↓
xmtp_client_manager.js (JavaScript)
       ↓
@xmtp/browser-sdk (XMTP SDK)
       ↓
XMTP Network
```

## Browser Compatibility

- Chrome 88+
- Firefox 85+
- Safari 14+
- Edge 88+

Requires WebAssembly support for cryptographic operations.

## Development Notes

### Content Types
The implementation includes a codec registry that supports:
- Text messages (`xmtp.org/text:1.0`)
- Attachments (`xmtp.org/attachment:1.0`)
- Remote attachments (`xmtp.org/remoteStaticAttachment:1.0`)

### Error Handling
All methods include comprehensive error handling with descriptive error messages. JavaScript errors are caught and converted to Dart exceptions.

### Real-time Messaging
Message streaming is implemented using the XMTP browser SDK's native streaming capabilities. Messages are forwarded to Flutter via JavaScript callbacks.

### Security
- Private keys are generated using browser's crypto.getRandomValues()
- All cryptographic operations use the XMTP SDK's built-in security
- No sensitive data is logged or exposed

## Troubleshooting

1. **"XMTP client not available" Error**
   - Ensure `xmtp_client_manager.js` is loaded before Flutter app
   - Check browser console for JavaScript errors

2. **"Method not found" Error**
   - Verify the XMTP browser SDK version compatibility
   - Check that all dependencies are installed

3. **CORS Issues**
   - Serve files from a web server, not file:// protocol
   - Ensure proper CORS headers if serving from custom server

4. **WebAssembly Issues**
   - Verify browser supports WebAssembly
   - Check browser compatibility requirements

## Version Compatibility

- XMTP Browser SDK: ^4.1.0
- Flutter: ^3.3.0
- Dart: ^3.5.4

This implementation provides full feature parity with the native Android and iOS implementations of the XMTP Flutter plugin.