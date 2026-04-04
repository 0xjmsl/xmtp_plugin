use std::sync::{Arc, LazyLock, Mutex};

use anyhow::{anyhow, Result};
use k256::ecdsa::SigningKey;
use sha3::{Digest, Keccak256};
use xmtp_db::{EncryptedMessageStore, EncryptionKey, NativeDb, StorageOption};
use xmtp_id::associations::unverified::UnverifiedSignature;
use xmtp_id::associations::Identifier;
use xmtp_mls::identity::IdentityStrategy;

/// The concrete XMTP client type used by libxmtp.
type RustXmtpClient = xmtp_mls::Client<xmtp_mls::MlsContext>;

/// Holds the initialized XMTP client and associated metadata.
pub(crate) struct ClientState {
    pub(crate) inner_client: Arc<RustXmtpClient>,
    pub(crate) account_address: String,
    pub(crate) inbox_id: String,
    /// The wallet private key used to initialize the client.
    /// Stored for signing operations (e.g., addAccount, revokeInstallations).
    pub(crate) signer_private_key: Vec<u8>,
    /// The XMTP network environment (production, dev, local).
    pub(crate) environment: String,
}

// SAFETY: RustXmtpClient uses Arc internally and is thread-safe.
unsafe impl Send for ClientState {}
unsafe impl Sync for ClientState {}

pub(crate) static CLIENT: LazyLock<Mutex<Option<ClientState>>> =
    LazyLock::new(|| Mutex::new(None));

// ---------------------------------------------------------------------------
// Public API — these functions are exposed to Dart via flutter_rust_bridge
// ---------------------------------------------------------------------------

/// Returns the platform version string.
pub fn get_platform_version() -> String {
    "Windows (Rust/libxmtp)".to_string()
}

/// Generate a random secp256k1 private key. Returns 32 raw bytes.
pub fn generate_private_key() -> Vec<u8> {
    let signing_key = SigningKey::random(&mut rand::rngs::OsRng);
    signing_key.to_bytes().to_vec()
}

/// Derive the Ethereum address from a 32-byte secp256k1 private key.
/// Returns a checksumless, lowercased, 0x-prefixed hex string (42 chars).
pub fn address_from_private_key(private_key: Vec<u8>) -> Result<String> {
    let key_bytes: [u8; 32] = private_key
        .try_into()
        .map_err(|_| anyhow!("Private key must be exactly 32 bytes"))?;
    let signing_key =
        SigningKey::from_bytes((&key_bytes).into()).map_err(|e| anyhow!("Invalid key: {e}"))?;
    Ok(eth_address_from_key(&signing_key))
}

/// Compute the XMTP inbox ID for a given Ethereum address.
/// The inbox ID is deterministic: sha256(lowercased_address + nonce).
pub fn compute_inbox_id(address: String) -> Result<String> {
    let identifier =
        Identifier::eth(&address).map_err(|e| anyhow!("Invalid Ethereum address: {e}"))?;
    let inbox_id = identifier
        .inbox_id(1)
        .map_err(|e| anyhow!("Failed to compute inbox ID: {e}"))?;
    Ok(inbox_id)
}

/// Resolve an environment string to (grpc_host, history_sync_url, is_secure).
pub(crate) fn resolve_environment(environment: &str) -> (&'static str, &'static str, bool) {
    match environment {
        "dev" => (
            "https://grpc.dev.xmtp.network:443",
            "https://message-history.dev.ephemera.network",
            true,
        ),
        "local" => (
            "http://localhost:5556",
            "http://localhost:5558",
            false,
        ),
        _ => (
            "https://grpc.production.xmtp.network:443",
            "https://message-history.production.ephemera.network",
            true,
        ),
    }
}

/// Initialize an XMTP client with the given private key and database encryption key.
///
/// Connects to the specified XMTP network environment, creates (or opens) an encrypted
/// local database, and registers the identity if needed.
///
/// Automatically looks up the address's inbox ID on the network first (handles
/// linked accounts via `addAccount`). Falls back to computing a fresh inbox ID
/// if the address is not yet registered.
///
/// Returns the Ethereum address of the initialized client.
pub async fn initialize_client(
    private_key: Vec<u8>,
    db_encryption_key: Vec<u8>,
    environment: String,
) -> Result<String> {
    let (grpc_host, history_sync_url, is_secure) = resolve_environment(&environment);
    // 1. Reconstruct signing key from raw bytes
    let signer_key_copy = private_key.clone();
    let key_bytes: [u8; 32] = private_key
        .try_into()
        .map_err(|_| anyhow!("Private key must be exactly 32 bytes"))?;
    let signing_key =
        SigningKey::from_bytes((&key_bytes).into()).map_err(|e| anyhow!("Invalid key: {e}"))?;

    // 2. Derive Ethereum address
    let address = eth_address_from_key(&signing_key);

    // 3. Create XMTP identifier
    let identifier =
        Identifier::eth(&address).map_err(|e| anyhow!("Invalid address: {e}"))?;
    let nonce: u64 = 1;

    // 4. Create encrypted database
    let db_key: EncryptionKey = db_encryption_key
        .try_into()
        .map_err(|_| anyhow!("DB encryption key must be exactly 32 bytes"))?;

    let db_dir = std::env::temp_dir().join("xmtp_plugin");
    std::fs::create_dir_all(&db_dir)?;
    let db_path = db_dir.join(format!("{}.db3", &address[2..10]));
    let storage_opt = StorageOption::Persistent(db_path.to_string_lossy().to_string());

    let db = NativeDb::new(&storage_opt, db_key)?;
    let store = EncryptedMessageStore::new(db)?;

    // 5. Build API clients (gRPC connections to XMTP network)
    //    MessageBackendBuilder wraps the raw gRPC bundle into FullXmtpApiArc
    //    which implements XmtpApi + XmtpQuery (required by Client::builder).
    use xmtp_api::ApiClientWrapper;
    use xmtp_api_d14n::MessageBackendBuilder;

    let api_client = MessageBackendBuilder::default()
        .v3_host(grpc_host)
        .maybe_gateway_host(None::<String>)
        .is_secure(is_secure)
        .readonly(false)
        .app_version("xmtp-flutter-windows/0.1.0")
        .build()
        .map_err(|e| anyhow!("Failed to build API client: {e}"))?;
    let sync_api_client = MessageBackendBuilder::default()
        .v3_host(grpc_host)
        .maybe_gateway_host(None::<String>)
        .is_secure(is_secure)
        .readonly(false)
        .app_version("xmtp-flutter-windows/0.1.0")
        .build()
        .map_err(|e| anyhow!("Failed to build sync API client: {e}"))?;

    // 6. Look up inbox ID from the network (handles linked accounts)
    //    If the address is already associated with an inbox (e.g., via addAccount),
    //    use that inbox ID. Otherwise, compute a fresh one.
    let lookup_client = MessageBackendBuilder::default()
        .v3_host(grpc_host)
        .maybe_gateway_host(None::<String>)
        .is_secure(is_secure)
        .build()
        .map_err(|e| anyhow!("Failed to build lookup client: {e}"))?;
    let lookup_api = ApiClientWrapper::new(
        std::sync::Arc::new(lookup_client),
        xmtp_api::strategies::exponential_cooldown(),
    );
    let api_ident: xmtp_proto::types::ApiIdentifier = identifier.clone().into();
    let inbox_id_map = lookup_api
        .get_inbox_ids(vec![api_ident.clone()])
        .await
        .map_err(|e| anyhow!("Failed to look up inbox ID: {e}"))?;
    let inbox_id = match inbox_id_map.get(&api_ident) {
        Some(existing_id) => existing_id.clone(),
        None => identifier
            .inbox_id(nonce)
            .map_err(|e| anyhow!("Failed to compute inbox ID: {e}"))?,
    };

    // 6. Create identity strategy and build client
    //    If the local DB has a stale inbox ID (e.g., key was added to a different
    //    inbox via addAccount), delete the DB and retry once with a fresh one.
    let xmtp_client = {
        let strategy = IdentityStrategy::new(
            inbox_id.clone(),
            identifier.clone(),
            nonce,
            None, // no legacy signed private key
        );

        let build_result = xmtp_mls::Client::builder(strategy)
            .api_clients(api_client, sync_api_client)
            .enable_api_stats()?
            .enable_api_debug_wrapper()?
            .with_remote_verifier()?
            .with_allow_offline(Some(true))
            .device_sync_server_url(history_sync_url)
            .store(store)
            .default_mls_store()?
            .build()
            .await;

        match build_result {
            Ok(client) => client,
            Err(e) => {
                let err_str = e.to_string();
                if err_str.contains("does not match the stored InboxId") {
                    tracing::warn!(
                        "Inbox ID mismatch detected — deleting stale DB at {:?} and retrying",
                        db_path
                    );
                    // Delete the stale DB file and retry
                    let _ = std::fs::remove_file(&db_path);
                    // Also remove WAL/SHM files if they exist
                    let wal_path = db_path.with_extension("db3-wal");
                    let shm_path = db_path.with_extension("db3-shm");
                    let _ = std::fs::remove_file(&wal_path);
                    let _ = std::fs::remove_file(&shm_path);

                    // Recreate DB and store
                    let db2 = NativeDb::new(&storage_opt, db_key)?;
                    let store2 = EncryptedMessageStore::new(db2)?;

                    // Rebuild API clients (consumed by first attempt)
                    let api_client2 = MessageBackendBuilder::default()
                        .v3_host(grpc_host)
                        .maybe_gateway_host(None::<String>)
                        .is_secure(is_secure)
                        .readonly(false)
                        .app_version("xmtp-flutter-windows/0.1.0")
                        .build()
                        .map_err(|e| anyhow!("Failed to build API client (retry): {e}"))?;
                    let sync_api_client2 = MessageBackendBuilder::default()
                        .v3_host(grpc_host)
                        .maybe_gateway_host(None::<String>)
                        .is_secure(is_secure)
                        .readonly(false)
                        .app_version("xmtp-flutter-windows/0.1.0")
                        .build()
                        .map_err(|e| anyhow!("Failed to build sync API client (retry): {e}"))?;

                    let strategy2 = IdentityStrategy::new(
                        inbox_id.clone(),
                        identifier.clone(),
                        nonce,
                        None,
                    );

                    xmtp_mls::Client::builder(strategy2)
                        .api_clients(api_client2, sync_api_client2)
                        .enable_api_stats()?
                        .enable_api_debug_wrapper()?
                        .with_remote_verifier()?
                        .with_allow_offline(Some(true))
                        .device_sync_server_url(history_sync_url)
                        .store(store2)
                        .default_mls_store()?
                        .build()
                        .await
                        .map_err(|e| anyhow!("Failed to build XMTP client after DB reset: {e}"))?
                } else {
                    return Err(anyhow!("Failed to build XMTP client: {e}"));
                }
            }
        }
    };

    // 8. Handle identity registration if needed
    if let Some(mut signature_request) = xmtp_client.identity().signature_request() {
        let text = signature_request.signature_text();
        // EIP-191 personal sign: prefix the message
        let prefixed = format!(
            "\x19Ethereum Signed Message:\n{}{}",
            text.len(),
            text
        );
        let digest = Keccak256::digest(prefixed.as_bytes());

        // Sign with recoverable ECDSA
        let (sig, recid) = signing_key
            .sign_prehash_recoverable(&digest)
            .map_err(|e| anyhow!("Failed to sign identity request: {e}"))?;

        // Build 65-byte recoverable signature: r (32) + s (32) + v (1)
        let mut sig_bytes = Vec::with_capacity(65);
        sig_bytes.extend_from_slice(&sig.to_bytes());
        sig_bytes.push(recid.to_byte());

        // Add the signature to the request using the core API
        let unverified = UnverifiedSignature::new_recoverable_ecdsa(sig_bytes);
        let verifier = xmtp_client.scw_verifier();
        signature_request
            .add_signature(unverified, &*verifier)
            .await
            .map_err(|e| anyhow!("Failed to add signature: {e}"))?;

        // Register the identity with the network
        xmtp_client
            .register_identity(signature_request)
            .await
            .map_err(|e| anyhow!("Failed to register identity: {e}"))?;
    }

    // 9. Store client in global state
    let state = ClientState {
        inner_client: Arc::new(xmtp_client),
        account_address: address.clone(),
        inbox_id,
        signer_private_key: signer_key_copy,
        environment,
    };

    let mut guard = CLIENT
        .lock()
        .map_err(|_| anyhow!("Client mutex poisoned"))?;
    *guard = Some(state);

    Ok(address)
}

/// Get the current client's Ethereum address.
/// Returns an error if no client has been initialized.
pub fn get_client_address() -> Result<String> {
    let guard = CLIENT
        .lock()
        .map_err(|_| anyhow!("Client mutex poisoned"))?;
    guard
        .as_ref()
        .map(|s| s.account_address.clone())
        .ok_or_else(|| anyhow!("Client not initialized. Call initializeClient first."))
}

/// Get the current client's XMTP inbox ID.
/// Returns an error if no client has been initialized.
pub fn get_client_inbox_id() -> Result<String> {
    let guard = CLIENT
        .lock()
        .map_err(|_| anyhow!("Client mutex poisoned"))?;
    guard
        .as_ref()
        .map(|s| s.inbox_id.clone())
        .ok_or_else(|| anyhow!("Client not initialized. Call initializeClient first."))
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Derive a lowercased, 0x-prefixed Ethereum address from a secp256k1 signing key.
fn eth_address_from_key(signing_key: &SigningKey) -> String {
    use k256::ecdsa::VerifyingKey;
    let verifying_key = VerifyingKey::from(signing_key);
    let public_key = verifying_key.to_encoded_point(false);
    // Skip the 0x04 prefix byte, hash the 64-byte uncompressed public key
    let hash = Keccak256::digest(&public_key.as_bytes()[1..]);
    // Ethereum address = last 20 bytes of the Keccak256 hash
    format!("0x{}", hex::encode(&hash[12..]))
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_private_key_length() {
        let key = generate_private_key();
        assert_eq!(key.len(), 32, "Private key must be 32 bytes");
    }

    #[test]
    fn test_generate_private_key_uniqueness() {
        let key1 = generate_private_key();
        let key2 = generate_private_key();
        assert_ne!(key1, key2, "Two generated keys should differ");
    }

    #[test]
    fn test_address_from_private_key_format() {
        let key = generate_private_key();
        let address = address_from_private_key(key).unwrap();
        assert!(address.starts_with("0x"), "Address must start with 0x");
        assert_eq!(address.len(), 42, "Address must be 42 characters");
        assert!(
            address[2..].chars().all(|c| c.is_ascii_hexdigit()),
            "Address must be valid hex"
        );
    }

    #[test]
    fn test_address_from_private_key_deterministic() {
        let key = generate_private_key();
        let addr1 = address_from_private_key(key.clone()).unwrap();
        let addr2 = address_from_private_key(key).unwrap();
        assert_eq!(addr1, addr2, "Same key must produce same address");
    }

    #[test]
    fn test_address_from_private_key_lowercased() {
        let key = generate_private_key();
        let address = address_from_private_key(key).unwrap();
        assert_eq!(
            address,
            address.to_lowercase(),
            "Address must be lowercased"
        );
    }

    #[test]
    fn test_address_from_invalid_key() {
        let result = address_from_private_key(vec![0u8; 16]);
        assert!(result.is_err(), "Should reject keys != 32 bytes");

        let result = address_from_private_key(vec![0u8; 64]);
        assert!(result.is_err(), "Should reject keys != 32 bytes");

        let result = address_from_private_key(vec![]);
        assert!(result.is_err(), "Should reject empty key");
    }

    #[test]
    fn test_compute_inbox_id_deterministic() {
        let key = generate_private_key();
        let address = address_from_private_key(key).unwrap();
        let id1 = compute_inbox_id(address.clone()).unwrap();
        let id2 = compute_inbox_id(address).unwrap();
        assert_eq!(id1, id2, "Same address must produce same inbox ID");
    }

    #[test]
    fn test_compute_inbox_id_format() {
        let key = generate_private_key();
        let address = address_from_private_key(key).unwrap();
        let inbox_id = compute_inbox_id(address).unwrap();
        assert_eq!(inbox_id.len(), 64, "Inbox ID must be 64 hex chars");
        assert!(
            inbox_id.chars().all(|c| c.is_ascii_hexdigit()),
            "Inbox ID must be valid hex"
        );
    }

    #[test]
    fn test_compute_inbox_id_different_addresses() {
        let key1 = generate_private_key();
        let key2 = generate_private_key();
        let addr1 = address_from_private_key(key1).unwrap();
        let addr2 = address_from_private_key(key2).unwrap();
        let id1 = compute_inbox_id(addr1).unwrap();
        let id2 = compute_inbox_id(addr2).unwrap();
        assert_ne!(id1, id2, "Different addresses must have different inbox IDs");
    }

    #[test]
    fn test_compute_inbox_id_invalid_address() {
        let result = compute_inbox_id("not_an_address".to_string());
        assert!(result.is_err(), "Should reject invalid addresses");

        let result = compute_inbox_id("0x".to_string());
        assert!(result.is_err(), "Should reject too-short addresses");
    }

    #[test]
    fn test_get_client_address_before_init() {
        let mut guard = CLIENT.lock().unwrap();
        *guard = None;
        drop(guard);

        let result = get_client_address();
        assert!(result.is_err(), "Should fail before initialization");
    }

    #[test]
    fn test_get_client_inbox_id_before_init() {
        let mut guard = CLIENT.lock().unwrap();
        *guard = None;
        drop(guard);

        let result = get_client_inbox_id();
        assert!(result.is_err(), "Should fail before initialization");
    }

    #[test]
    fn test_known_address_derivation() {
        // Known test vector: private key = 1
        let key = vec![
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
        ];
        let address = address_from_private_key(key).unwrap();
        assert_eq!(
            address, "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf",
            "Known test vector: private key 0x01"
        );
    }
}
