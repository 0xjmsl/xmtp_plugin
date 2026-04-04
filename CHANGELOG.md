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
* Platform support: Android (xmtp-android SDK), iOS/macOS (XMTP Swift SDK), Windows (Rust FFI via libxmtp), Web (XMTP Browser SDK v5)
