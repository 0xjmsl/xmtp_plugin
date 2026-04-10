import Flutter
import UIKit
import XMTP
import Foundation

struct ContentType {
    let authorityId: String
    let typeId: String
    let versionMajor: Int
}

struct GroupOptions {
    let name: String?
    let description: String?
    let imageUrl: String?
    let pinnedFrameUrl: String?
}

public class XmtpPlugin: NSObject, FlutterPlugin {
    private var client: XMTP.Client?
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "xmtp_plugin", binaryMessenger: registrar.messenger())
        let instance = XmtpPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "generatePrivateKey":
            generatePrivateKey(result: result)
            
        case "initializeClient":
            guard let args = call.arguments as? [String: Any],
                  let privateKey = args["privateKey"] as? FlutterStandardTypedData,
                  let dbKey = args["dbKey"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Key and dbKey are required", details: nil))
                return
            }
            let environment = args["environment"] as? String ?? "production"
            initializeClient(privateKey: privateKey.data, dbKey: dbKey.data, environment: environment, result: result)
            
        case "getClientAddress":
            getClientAddress(result: result)
            
        case "getClientInboxId":
            getClientInboxId(result: result)
            
        case "sendMessage":
            guard let args = call.arguments as? [String: Any],
                  let recipientAddress = args["recipientAddress"] as? String,
                  let message = args["message"] as? [String: Any],
                  let contentType = getContentType(from: args) else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Recipient address, message and content type are required", details: nil))
                return
            }
            sendMessage(recipientAddress: recipientAddress, message: message, contentType: contentType, result: result)
            
        case "sendMessageByInboxId":
            guard let args = call.arguments as? [String: Any],
                  let recipientInboxId = args["recipientInboxId"] as? String,
                  let message = args["message"] as? [String: Any],
                  let contentType = getContentType(from: args) else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "recipientInboxId, message and content type are required", details: nil))
                return
            }
            sendMessageByInboxId(recipientInboxId: recipientInboxId, message: message, contentType: contentType, result: result)
            
        case "sendGroupMessage":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let message = args["message"] as? [String: Any],
                  let contentType = getContentType(from: args) else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic, message and content type are required", details: nil))
                return
            }
            sendGroupMessage(topic: topic, message: message, contentType: contentType, result: result)
            
        case "subscribeToAllMessages":
            subscribeToAllMessages(result: result)

        case "getConversationConsentState":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "topic is required", details: nil))
                return
            }
            getConversationConsentState(topic: topic, result: result)

        case "setConversationConsentState":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let state = args["state"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "topic and state are required", details: nil))
                return
            }
            setConversationConsentState(topic: topic, state: state, result: result)

        case "getInboxConsentState":
            guard let args = call.arguments as? [String: Any],
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "inboxId is required", details: nil))
                return
            }
            getInboxConsentState(inboxId: inboxId, result: result)

        case "setInboxConsentState":
            guard let args = call.arguments as? [String: Any],
                  let inboxId = args["inboxId"] as? String,
                  let state = args["state"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "inboxId and state are required", details: nil))
                return
            }
            setInboxConsentState(inboxId: inboxId, state: state, result: result)

        case "syncConsentPreferences":
            syncConsentPreferences(result: result)

        case "sendSyncRequest":
            sendSyncRequest(result: result)

        case "syncAll":
            let consentStates = (call.arguments as? [String: Any])?["consentStates"] as? [String]
            syncAll(consentStates: consentStates, result: result)

        case "syncConversation":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic is required", details: nil))
                return
            }
            syncConversation(topic: topic, result: result)

        case "listDms":
            let consentState = (call.arguments as? [String: Any])?["consentState"] as? String
            listDms(consentState: consentState, result: result)

        case "listGroups":
            let consentState = (call.arguments as? [String: Any])?["consentState"] as? String
            listGroups(consentState: consentState, result: result)
            
        case "newGroup":
            guard let args = call.arguments as? [String: Any],
                  let inboxIds = args["inboxIds"] as? [String],
                  let options = args["options"] as? [String: String] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "inboxIds list and options map are required", details: nil))
                return
            }
            
            let groupOptions = GroupOptions(
                name: options["name"],
                description: options["description"],
                imageUrl: options["imageUrl"],
                pinnedFrameUrl: options["pinnedFrameUrl"]
            )
            newGroup(inboxIds: inboxIds, options: groupOptions, result: result)
            
        case "listGroupMembers":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "topic is required", details: nil))
                return
            }
            listGroupMembers(topic: topic, result: result)
            
        case "listGroupAdmins":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic is required", details: nil))
                return
            }
            listGroupAdmins(topic: topic, result: result)
            
        case "listGroupSuperAdmins":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic is required", details: nil))
                return
            }
            listGroupSuperAdmins(topic: topic, result: result)
            
        case "addGroupMembers":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let inboxIds = args["inboxIds"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and inboxIds are required", details: nil))
                return
            }
            addGroupMembers(topic: topic, inboxIds: inboxIds, result: result)
            
        case "removeGroupMembers":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let inboxIds = args["inboxIds"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and inboxIds are required", details: nil))
                return
            }
            removeGroupMembers(topic: topic, inboxIds: inboxIds, result: result)
            
        case "addGroupAdmin":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and inboxId are required", details: nil))
                return
            }
            addGroupAdmin(topic: topic, inboxId: inboxId, result: result)
            
        case "removeGroupAdmin":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and inboxId are required", details: nil))
                return
            }
            removeGroupAdmin(topic: topic, inboxId: inboxId, result: result)
            
        case "addGroupSuperAdmin":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and inboxId are required", details: nil))
                return
            }
            addGroupSuperAdmin(topic: topic, inboxId: inboxId, result: result)
            
        case "removeGroupSuperAdmin":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and inboxId are required", details: nil))
                return
            }
            removeGroupSuperAdmin(topic: topic, inboxId: inboxId, result: result)
            
        case "updateGroup":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let updates = args["updates"] as? [String: String] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and updates are required", details: nil))
                return
            }
            updateGroup(topic: topic, updates: updates, result: result)
            
        case "getGroupMemberRole":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and inboxId are required", details: nil))
                return
            }
            getGroupMemberRole(topic: topic, inboxId: inboxId, result: result)
            
        case "canMessageByAddress":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Address is required", details: nil))
                return
            }
            canMessage(address: address, result: result)

        case "canMessageByInboxId":
            guard let args = call.arguments as? [String: Any],
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Inbox ID is required", details: nil))
                return
            }
            canMessageByInboxId(inboxId: inboxId, result: result)
            
        case "findOrCreateDMWithInboxId":
            guard let args = call.arguments as? [String: Any],
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "inboxId is required", details: nil))
                return
            }
            findOrCreateDMWithInboxId(inboxId: inboxId, result: result)
            
        case "inboxIdFromAddress":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Address is required", details: nil))
                return
            }
            inboxIdFromAddress(address: address, result: result)
            
        case "getMessagesAfterDate":
            guard let args = call.arguments as? [String: Any],
                  let peerAddress = args["peerAddress"] as? String,
                  let fromDate = args["fromDate"] as? Int64 else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Peer address and from date are required", details: nil))
                return
            }
            getMessagesAfterDate(peerAddress: peerAddress, fromDate: fromDate, result: result)
            
        case "getMessagesAfterDateByTopic":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String,
                  let fromDate = args["fromDate"] as? Int64 else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic and from date are required", details: nil))
                return
            }
            getMessagesAfterDateByTopic(topic: topic, fromDate: fromDate, result: result)
            
        case "loadRemoteAttachment":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments are required", details: nil))
                return
            }
            loadRemoteAttachment(args: args, result: result)
            
        case "conversationTopicFromAddress":
            guard let args = call.arguments as? [String: Any],
                  let peerAddress = args["peerAddress"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "peerAddress is required for conversationTopicFromAddress", details: nil))
                return
            }
            conversationTopicFromAddress(peerAddress: peerAddress, result: result)

        case "inboxStatesForInboxIds":
            guard let args = call.arguments as? [String: Any],
                  let inboxIds = args["inboxIds"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "inboxIds are required", details: nil))
                return
            }
            let refreshFromNetwork = (args["refreshFromNetwork"] as? Bool) ?? false  // Changed default to false
            inboxStatesForInboxIds(inboxIds: inboxIds, refreshFromNetwork: refreshFromNetwork, result: result)

        case "syncAll":
            let consentStates = (call.arguments as? [String: Any])?["consentStates"] as? [String] ?? ["allowed"]
            syncAll(consentStates: consentStates, result: result)

        case "syncConversation":
            guard let args = call.arguments as? [String: Any],
                  let topic = args["topic"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Topic is required", details: nil))
                return
            }
            syncConversation(topic: topic, result: result)

        // ============================================================================
        // INBOX MANAGEMENT METHODS
        // ============================================================================
        case "getInstallationId":
            getInstallationId(result: result)

        case "inboxState":
            let refreshFromNetwork = (call.arguments as? [String: Any])?["refreshFromNetwork"] as? Bool ?? false
            inboxState(refreshFromNetwork: refreshFromNetwork, result: result)

        case "revokeInstallations":
            guard let args = call.arguments as? [String: Any],
                  let signerPrivateKey = args["signerPrivateKey"] as? FlutterStandardTypedData,
                  let installationIds = args["installationIds"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "signerPrivateKey and installationIds are required", details: nil))
                return
            }
            revokeInstallations(signerPrivateKey: signerPrivateKey.data, installationIds: installationIds, result: result)

        case "revokeAllOtherInstallations":
            guard let args = call.arguments as? [String: Any],
                  let signerPrivateKey = args["signerPrivateKey"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "signerPrivateKey is required", details: nil))
                return
            }
            revokeAllOtherInstallations(signerPrivateKey: signerPrivateKey.data, result: result)

        case "addAccount":
            guard let args = call.arguments as? [String: Any],
                  let newAccountPrivateKey = args["newAccountPrivateKey"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "newAccountPrivateKey is required", details: nil))
                return
            }
            let allowReassignInboxId = (args["allowReassignInboxId"] as? Bool) ?? false
            addAccount(newAccountPrivateKey: newAccountPrivateKey.data, allowReassignInboxId: allowReassignInboxId, result: result)

        case "removeAccount":
            guard let args = call.arguments as? [String: Any],
                  let recoveryPrivateKey = args["recoveryPrivateKey"] as? FlutterStandardTypedData,
                  let identifierToRemove = args["identifierToRemove"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "recoveryPrivateKey and identifierToRemove are required", details: nil))
                return
            }
            removeAccount(recoveryPrivateKey: recoveryPrivateKey.data, identifierToRemove: identifierToRemove, result: result)

        case "staticRevokeInstallations":
            guard let args = call.arguments as? [String: Any],
                  let signerPrivateKey = args["signerPrivateKey"] as? FlutterStandardTypedData,
                  let inboxId = args["inboxId"] as? String,
                  let installationIds = args["installationIds"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "signerPrivateKey, inboxId and installationIds are required", details: nil))
                return
            }
            staticRevokeInstallations(signerPrivateKey: signerPrivateKey.data, inboxId: inboxId, installationIds: installationIds, result: result)

        case "staticInboxStatesForInboxIds":
            guard let args = call.arguments as? [String: Any],
                  let inboxIds = args["inboxIds"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "inboxIds is required", details: nil))
                return
            }
            staticInboxStatesForInboxIds(inboxIds: inboxIds, result: result)

        case "staticGetInboxIdForAddress":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "address is required", details: nil))
                return
            }
            let environment = args["environment"] as? String ?? "production"
            staticGetInboxIdForAddress(address: address, environment: environment, result: result)

        case "staticDeleteLocalDatabase":
            guard let args = call.arguments as? [String: Any],
                  let inboxId = args["inboxId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "inboxId is required", details: nil))
                return
            }
            let environment = args["environment"] as? String ?? "production"
            staticDeleteLocalDatabase(inboxId: inboxId, environment: environment, result: result)

        case "changeRecoveryIdentifier":
            // Not supported on iOS - only on web/JS
            result(FlutterError(code: "UNSUPPORTED_PLATFORM", message: "changeRecoveryIdentifier is only supported on web platforms", details: nil))

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getContentType(from args: [String: Any]) -> ContentType? {
        guard let authorityId = args["authorityId"] as? String,
              let typeId = args["typeId"] as? String,
              let versionMajor = args["versionMajor"] as? Int else {
            return nil
        }
        
        return ContentType(authorityId: authorityId, typeId: typeId, versionMajor: versionMajor)
    }
    
    // MARK: - Private Key Generation
    private func generatePrivateKey(result: @escaping FlutterResult) {
        do {
            let privateKey = try PrivateKey.generate()
            let privateKeyData = privateKey.secp256K1.bytes
            result(FlutterStandardTypedData(bytes: privateKeyData))
        } catch {
            result(FlutterError(code: "KEY_GENERATION_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Client Initialization
    private func resolveEnvironment(_ env: String) -> XMTPEnvironment {
        switch env.lowercased() {
        case "dev": return .dev
        case "local": return .local
        default: return .production
        }
    }

    private func initializeClient(privateKey: Data, dbKey: Data, environment: String, result: @escaping FlutterResult) {
        Task {
            do {
                let privateKey = try PrivateKey(privateKey)

                let xmtpEnv = resolveEnvironment(environment)
                let options = ClientOptions(
                    api: ClientOptions.Api(env: xmtpEnv, isSecure: xmtpEnv != .local),
                    dbEncryptionKey: dbKey
                )
                
                // Register codecs
                XMTP.Client.register(codec: AttachmentCodec())
                XMTP.Client.register(codec: RemoteAttachmentCodec())
                
                let client = try await XMTP.Client.create(account: privateKey, options: options)
                self.client = client
                
                DispatchQueue.main.async {
                    result(client.publicIdentity.identifier)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CLIENT_INITIALIZATION_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Client Info
    private func getClientAddress(result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        result(client.publicIdentity.identifier)
    }
    
    private func getClientInboxId(result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        result(client.inboxID)
    }
    
    // MARK: - Message Sending
    private func sendMessage(recipientAddress: String, message: [String: Any], contentType: ContentType, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                let publicIdentity = PublicIdentity(kind: .ethereum, identifier: recipientAddress)
                let conversation = try await client.conversations.findOrCreateDmWithIdentity(with: publicIdentity)
                
                guard let content = message["content"] as? FlutterStandardTypedData,
                      let parameters = message["parameters"] as? [String: String] else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_MESSAGE", message: "Content must be provided", details: nil))
                    }
                    return
                }
                
                let encodedContent = try createEncodedContent(
                    contentType: contentType,
                    content: content.data,
                    parameters: parameters
                )
                
                let messageId = try await conversation.send(encodedContent: encodedContent)
                
                DispatchQueue.main.async {
                    result(messageId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "MESSAGE_SEND_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func sendMessageByInboxId(recipientInboxId: String, message: [String: Any], contentType: ContentType, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                let conversation = try await client.conversations.findOrCreateDm(with: recipientInboxId)
                
                guard let content = message["content"] as? FlutterStandardTypedData,
                      let parameters = message["parameters"] as? [String: String] else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_MESSAGE", message: "Content must be provided", details: nil))
                    }
                    return
                }
                
                let encodedContent = try createEncodedContent(
                    contentType: contentType,
                    content: content.data,
                    parameters: parameters
                )
                
                let messageId = try await conversation.send(encodedContent: encodedContent)
                
                DispatchQueue.main.async {
                    result(messageId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "MESSAGE_SEND_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func sendGroupMessage(topic: String, message: [String: Any], contentType: ContentType, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "CONVERSATION_NOT_FOUND", message: "Group conversation not found", details: nil))
                    }
                    return
                }
                
                guard case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                guard let content = message["content"] as? FlutterStandardTypedData,
                      let parameters = message["parameters"] as? [String: String] else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_MESSAGE", message: "Content must be provided", details: nil))
                    }
                    return
                }
                
                let encodedContent = try createEncodedContent(
                    contentType: contentType,
                    content: content.data,
                    parameters: parameters
                )
                
                let messageId = try await group.send(encodedContent: encodedContent)
                
                DispatchQueue.main.async {
                    result(messageId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GROUP_MESSAGE_SEND_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Sync Methods
    private func syncAll(consentStates: [String]?, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                // Convert consent state strings to ConsentState array
                let states: [ConsentState] = consentStates?.compactMap { stateStr in
                    switch stateStr.lowercased() {
                    case "allowed": return .allowed
                    case "denied": return .denied
                    case "unknown": return .unknown
                    default: return nil
                    }
                } ?? [.allowed]

                let summary = try await client.conversations.syncAllConversations(consentStates: states)

                DispatchQueue.main.async {
                    result(["numGroupsSynced": summary.numSynced])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SYNC_ALL_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func syncConversation(topic: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                if let conversation = try await client.conversations.findConversationByTopic(topic: topic) {
                    try await conversation.sync()
                }
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SYNC_CONVERSATION_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Conversation Management
    private func listDms(consentState: String?, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                // Sync removed - now local-only read. Call syncAll() explicitly when needed.

                // Convert consent state string to ConsentState array
                let consentStates: [ConsentState]? = {
                    guard let state = consentState else { return nil }
                    switch state.lowercased() {
                    case "allowed": return [.allowed]
                    case "denied": return [.denied]
                    case "unknown": return [.unknown]
                    default: return nil
                    }
                }()

                let dms = try client.conversations.listDms(consentStates: consentStates)

                let dmList = try await dms.asyncMap { dm in
                    let members = try await dm.members
                    return [
                        "id": dm.id,
                        "topic": dm.topic,
                        "createdAt": Int64(dm.createdAt.timeIntervalSince1970 * 1000),
                        "peerInboxId": try dm.peerInboxId,
                        "members": members.map { member in
                            [
                                "inboxId": member.inboxId,
                                "addresses": member.identities.first?.identifier
                            ]
                        }
                    ]
                }

                DispatchQueue.main.async {
                    result(dmList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LIST_CONVERSATIONS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func listGroups(consentState: String?, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                // Sync removed - now local-only read. Call syncAll() explicitly when needed.

                // Convert consent state string to ConsentState array
                let consentStates: [ConsentState]? = {
                    guard let state = consentState else { return nil }
                    switch state.lowercased() {
                    case "allowed": return [.allowed]
                    case "denied": return [.denied]
                    case "unknown": return [.unknown]
                    default: return nil
                    }
                }()

                let groups = try client.conversations.listGroups(consentStates: consentStates)

                let groupList = try await groups.asyncMap { group in
                    let members = try await group.members
                    return [
                        "id": group.id,
                        "topic": group.topic,
                        "createdAt": Int64(group.createdAt.timeIntervalSince1970 * 1000),
                        "name": try group.name(),
                        "imageUrlSquare": try group.imageUrl(),
                        "description": try group.description(),
                        "members": members.map { member in
                            [
                                "inboxId": member.inboxId,
                                "addresses": member.identities.first?.identifier
                            ]
                        }
                    ]
                }

                DispatchQueue.main.async {
                    result(groupList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LIST_CONVERSATIONS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func newGroup(inboxIds: [String], options: GroupOptions, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                let group = try await client.conversations.newGroup(
                    with: inboxIds,
                    name: options.name ?? "",
                    imageUrl: options.imageUrl ?? "",
                    description: options.description ?? ""
                )
                
                let groupMap: [String: Any] = [
                    "id": group.id,
                    "topic": group.topic,
                    "createdAt": String(Int64(group.createdAt.timeIntervalSince1970 * 1000)),
                    "name": try group.name(),
                    "imageUrlSquare": try group.imageUrl(),
                    "description": try group.description()
                ]
                
                DispatchQueue.main.async {
                    result(groupMap)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GROUP_CREATION_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Group Management
    private func listGroupMembers(topic: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                let members = try await group.members
                let memberList = members.map { member in
                    [
                        "inboxId": member.inboxId,
                        "address": member.identities.first?.identifier
                    ]
                }
                
                DispatchQueue.main.async {
                    result(memberList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LIST_MEMBERS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func listGroupAdmins(topic: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                let admins = try group.listAdmins()
                let adminList = admins.map { adminId in
                    ["inboxId": adminId]
                }
                
                DispatchQueue.main.async {
                    result(adminList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LIST_ADMINS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func listGroupSuperAdmins(topic: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                let superAdmins = try group.listSuperAdmins()
                let superAdminList = superAdmins.map { adminId in
                    ["inboxId": adminId]
                }
                
                DispatchQueue.main.async {
                    result(superAdminList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LIST_SUPER_ADMINS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func addGroupMembers(topic: String, inboxIds: [String], result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                _ = try await group.addMembers(inboxIds: inboxIds)
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ADD_MEMBERS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func removeGroupMembers(topic: String, inboxIds: [String], result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                try await group.removeMembers(inboxIds: inboxIds)
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "REMOVE_MEMBERS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func addGroupAdmin(topic: String, inboxId: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                try await group.addAdmin(inboxId: inboxId)
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ADD_ADMIN_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func removeGroupAdmin(topic: String, inboxId: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                try await group.removeAdmin(inboxId: inboxId)
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "REMOVE_ADMIN_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func addGroupSuperAdmin(topic: String, inboxId: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                try await group.addSuperAdmin(inboxId: inboxId)
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ADD_SUPER_ADMIN_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func removeGroupSuperAdmin(topic: String, inboxId: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                try await group.removeSuperAdmin(inboxId: inboxId)
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "REMOVE_SUPER_ADMIN_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func updateGroup(topic: String, updates: [String: String], result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                if let name = updates["name"] {
                    try await group.updateName(name: name)
                }
                
                if let description = updates["description"] {
                    try await group.updateDescription(description: description)
                }
                
                if let imageUrl = updates["imageUrl"] {
                    try await group.updateImageUrl(imageUrl: imageUrl)
                }
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "UPDATE_GROUP_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func getGroupMemberRole(topic: String, inboxId: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic),
                      case .group(let group) = conversation else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_A_GROUP", message: "Conversation is not a group", details: nil))
                    }
                    return
                }
                
                let isAdmin = try group.isAdmin(inboxId: inboxId)
                let isSuperAdmin = try group.isSuperAdmin(inboxId: inboxId)
                
                let roleMap: [String: Any] = [
                    "isAdmin": isAdmin,
                    "isSuperAdmin": isSuperAdmin
                ]
                
                DispatchQueue.main.async {
                    result(roleMap)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GET_MEMBER_ROLE_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    private func canMessage(address: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let publicIdentity = PublicIdentity(kind: .ethereum, identifier: address)
                let canMessage = try await client.canMessage(identity: publicIdentity)

                DispatchQueue.main.async {
                    result(canMessage)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CAN_MESSAGE_CHECK_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func canMessageByInboxId(inboxId: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                // Use inboxStatesForInboxIds to check if inbox ID exists
                let inboxStates = try await client.inboxStatesForInboxIds(refreshFromNetwork: true, inboxIds: [inboxId])

                // If we get a state back with matching inbox ID, it exists
                let canMessage = inboxStates.contains { $0.inboxId == inboxId }

                DispatchQueue.main.async {
                    result(canMessage)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CAN_MESSAGE_BY_INBOX_ID_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func inboxStatesForInboxIds(inboxIds: [String], refreshFromNetwork: Bool, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let inboxStates = try await client.inboxStatesForInboxIds(refreshFromNetwork: refreshFromNetwork, inboxIds: inboxIds)

                let statesList = inboxStates.map { state -> [String: Any] in
                    [
                        "inboxId": state.inboxId,
                        "identities": state.identities.map { identity in
                            [
                                "identifier": identity.identifier,
                                "kind": identity.kind == .ethereum ? "ethereum" : "passkey"
                            ]
                        },
                        "installations": state.installations.map { installation in
                            [
                                "id": installation.id,
                                "createdAt": installation.createdAt.map { Int64($0.timeIntervalSince1970 * 1000) } as Any
                            ]
                        },
                        "recoveryIdentity": [
                            "identifier": state.recoveryIdentity.identifier,
                            "kind": state.recoveryIdentity.kind == .ethereum ? "ethereum" : "passkey"
                        ]
                    ]
                }

                DispatchQueue.main.async {
                    result(statesList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INBOX_STATES_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func findOrCreateDMWithInboxId(inboxId: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                let dm = try await client.conversations.findOrCreateDm(with: inboxId)
                let members = try await dm.members
                
                let dmMap: [String: Any] = [
                    "id": dm.id,
                    "topic": dm.topic,
                    "createdAt": Int64(dm.createdAt.timeIntervalSince1970 * 1000),
                    "peerInboxId": try dm.peerInboxId,
                    "members": members.map { member in
                        [
                            "inboxId": member.inboxId,
                            "addresses": member.identities.first?.identifier
                        ]
                    }
                ]
                
                DispatchQueue.main.async {
                    result(dmMap)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "FIND_OR_CREATE_DM_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func inboxIdFromAddress(address: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                let publicIdentity = PublicIdentity(kind: .ethereum, identifier: address)
                let inboxId = try await client.inboxIdFromIdentity(identity: publicIdentity)
                
                DispatchQueue.main.async {
                    result(inboxId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "inboxIDfromAddress_CHECK_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func conversationTopicFromAddress(peerAddress: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                guard !peerAddress.isEmpty else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_ARGUMENTS", message: "peerAddress cannot be blank", details: nil))
                    }
                    return
                }
                
                let publicIdentity = PublicIdentity(kind: .ethereum, identifier: peerAddress)
                let conversation = try await client.conversations.findOrCreateDmWithIdentity(with: publicIdentity)
                
                DispatchQueue.main.async {
                    result(conversation.topic)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CONVERSATION_TOPIC_FAILED", message: "Failed to get conversation topic for \(peerAddress): \(error.localizedDescription)", details: nil))
                }
            }
        }
    }
    
    // MARK: - Message Retrieval
    private func getMessagesAfterDate(peerAddress: String, fromDate: Int64, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                try await client.conversations.sync()
                let publicIdentity = PublicIdentity(kind: .ethereum, identifier: peerAddress)
                let conversation = try await client.conversations.findOrCreateDmWithIdentity(with: publicIdentity)
                
                let afterNs = fromDate * 1_000_000 // Convert milliseconds to nanoseconds
                let messages = try await conversation.messages(afterNs: afterNs)
                
                let messageList = try await messages.asyncMap { message in
                    let members = try await conversation.members
                    return try createMessageMap(message: message, members: members, conversationTopic: conversation.topic)
                }
                
                DispatchQueue.main.async {
                    result(messageList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GET_MESSAGES_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func getMessagesAfterDateByTopic(topic: String, fromDate: Int64, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                try await client.conversations.sync()
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "CONVERSATION_NOT_FOUND", message: "Conversation not found", details: nil))
                    }
                    return
                }
                
                let afterNs = fromDate * 1_000_000 // Convert milliseconds to nanoseconds
                let messages: [DecodedMessage]
                let members: [Member]
                
                switch conversation {
                case .dm(let dm):
                    messages = try await dm.messages(afterNs: afterNs)
                    members = try await dm.members
                case .group(let group):
                    messages = try await group.messages(afterNs: afterNs)
                    members = try await group.members
                }
                
                let messageList = try await messages.asyncMap { message in
                    return try createMessageMap(message: message, members: members, conversationTopic: topic)
                }
                
                DispatchQueue.main.async {
                    result(messageList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GET_MESSAGES_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Consent Management
    private func getConversationConsentState(topic: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic) else {
                    DispatchQueue.main.async {
                        result("unknown")
                    }
                    return
                }

                let state: ConsentState
                switch conversation {
                case .dm(let dm):
                    state = try dm.consentState()
                case .group(let group):
                    state = try group.consentState()
                }

                DispatchQueue.main.async {
                    result(state.rawValue)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GET_CONSENT_STATE_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func setConversationConsentState(topic: String, state: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                guard let conversation = try await client.conversations.findConversationByTopic(topic: topic) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "CONVERSATION_NOT_FOUND", message: "Conversation with topic \(topic) not found", details: nil))
                    }
                    return
                }

                let consentState: ConsentState
                switch state.lowercased() {
                case "allowed":
                    consentState = .allowed
                case "denied":
                    consentState = .denied
                case "unknown":
                    consentState = .unknown
                default:
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_CONSENT_STATE", message: "Invalid consent state: \(state)", details: nil))
                    }
                    return
                }

                switch conversation {
                case .dm(let dm):
                    try await dm.updateConsentState(state: consentState)
                case .group(let group):
                    try await group.updateConsentState(state: consentState)
                }

                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SET_CONSENT_STATE_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func getInboxConsentState(inboxId: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let state = try await client.preferences.inboxIdState(inboxId: inboxId)
                DispatchQueue.main.async {
                    result(state.rawValue)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GET_INBOX_CONSENT_STATE_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func setInboxConsentState(inboxId: String, state: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let consentState: ConsentState
                switch state.lowercased() {
                case "allowed":
                    consentState = .allowed
                case "denied":
                    consentState = .denied
                case "unknown":
                    consentState = .unknown
                default:
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_CONSENT_STATE", message: "Invalid consent state: \(state)", details: nil))
                    }
                    return
                }

                let record = ConsentRecord(value: inboxId, entryType: .inbox_id, consentType: consentState)
                try await client.preferences.setConsentState(entries: [record])

                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SET_INBOX_CONSENT_STATE_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func syncConsentPreferences(result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                try await client.preferences.sync()
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SYNC_CONSENT_PREFERENCES_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func sendSyncRequest(result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                try await client.preferences.syncConsent()
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SEND_SYNC_REQUEST_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - Message Streaming
    private func subscribeToAllMessages(result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }
        
        Task {
            do {
                for try await message in client.conversations.streamAllMessages() {
                    // Find the conversation to get member information
                    if let conversation = try await client.conversations.findConversationByTopic(topic: message.topic) {
                        let members: [Member]
                        
                        switch conversation {
                        case .dm(let dm):
                            members = try await dm.members
                        case .group(let group):
                            members = try await group.members
                        }
                        
                        let messageMap = try createMessageMap(message: message, members: members, conversationTopic: message.topic)
                        
                        DispatchQueue.main.async {
                            self.channel?.invokeMethod("onMessageReceived", arguments: messageMap)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SUBSCRIPTION_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Attachment Support
    private func loadRemoteAttachment(args: [String: Any], result: @escaping FlutterResult) {
        Task {
            do {
                guard let urlString = args["url"] as? String,
                      let url = URL(string: urlString),
                      let contentDigest = args["contentDigest"] as? String,
                      let secretList = args["secret"] as? [Int],
                      let saltList = args["salt"] as? [Int],
                      let nonceList = args["nonce"] as? [Int],
                      let scheme = args["scheme"] as? String else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required parameters", details: nil))
                    }
                    return
                }
                
                let secretData = Data(secretList.map { UInt8($0) })
                let saltData = Data(saltList.map { UInt8($0) })
                let nonceData = Data(nonceList.map { UInt8($0) })
                let contentLength = args["contentLength"] as? Int
                let filename = args["filename"] as? String
                
                var remoteAttachment = try RemoteAttachment(
                    url: urlString,
                    contentDigest: contentDigest,
                    secret: secretData,
                    salt: saltData,
                    nonce: nonceData,
                    scheme: .https,
                    contentLength: contentLength,
                    filename: filename
                )
                
                let encodedContent = try await remoteAttachment.content()
                
                // Decode the attachment content
                let attachmentCodec = AttachmentCodec()
                let attachment = try attachmentCodec.decode(content: encodedContent)
                
                let attachmentMap: [String: Any?] = [
                    "filename": attachment.filename,
                    "mimeType": attachment.mimeType,
                    "data": FlutterStandardTypedData(bytes: attachment.data)
                ]
                
                DispatchQueue.main.async {
                    result(attachmentMap)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createEncodedContent(contentType: ContentType, content: Data, parameters: [String: String]) throws -> EncodedContent {
        var encodedContent = EncodedContent()
        
        encodedContent.type = ContentTypeID(
            authorityID: contentType.authorityId,
            typeID: contentType.typeId,
            versionMajor: contentType.versionMajor,
            versionMinor: 0
        )
        
        encodedContent.content = content
        encodedContent.parameters = parameters
        
        return encodedContent
    }
    
    private func createMessageMap(message: DecodedMessage, members: [Member], conversationTopic: String) throws -> [String: Any] {
        return [
            "id": message.id,
            "body": try message.body,
            "sent": Int64(message.sentAt.timeIntervalSince1970 * 1000),
            "conversationTopic": conversationTopic,
            "senderInboxId": message.senderInboxId,
            "encodedContent": FlutterStandardTypedData(bytes: try message.encodedContent.serializedData()),
            "members": members.map { member in
                [
                    "inboxId": member.inboxId,
                    "addresses": member.identities.first?.identifier
                ]
            }
        ]
    }

    // ============================================================================
    // MARK: - Inbox Management Methods
    // ============================================================================

    private func getInstallationId(result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        result(client.installationID)
    }

    private func inboxState(refreshFromNetwork: Bool, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let state = try await client.inboxState(refreshFromNetwork: refreshFromNetwork)

                let stateMap: [String: Any] = [
                    "inboxId": state.inboxId,
                    "identities": state.identities.map { identity in
                        [
                            "identifier": identity.identifier,
                            "kind": identity.kind == .ethereum ? "ethereum" : "passkey"
                        ]
                    },
                    "installations": state.installations.map { installation in
                        [
                            "id": installation.id,
                            "createdAt": installation.createdAt.map { Int64($0.timeIntervalSince1970 * 1000) } as Any
                        ]
                    },
                    "recoveryIdentity": [
                        "identifier": state.recoveryIdentity.identifier,
                        "kind": state.recoveryIdentity.kind == .ethereum ? "ethereum" : "passkey"
                    ]
                ]

                DispatchQueue.main.async {
                    result(stateMap)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INBOX_STATE_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func revokeInstallations(signerPrivateKey: Data, installationIds: [String], result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let signer = try PrivateKey(signerPrivateKey)
                try await client.revokeInstallations(signingKey: signer, installationIds: installationIds)

                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "REVOKE_INSTALLATIONS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func revokeAllOtherInstallations(signerPrivateKey: Data, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let signer = try PrivateKey(signerPrivateKey)
                try await client.revokeAllOtherInstallations(signingKey: signer)

                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "REVOKE_ALL_OTHER_INSTALLATIONS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func addAccount(newAccountPrivateKey: Data, allowReassignInboxId: Bool, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let newAccount = try PrivateKey(newAccountPrivateKey)
                try await client.addAccount(newAccount: newAccount, allowReassignInboxId: allowReassignInboxId)

                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ADD_ACCOUNT_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func removeAccount(recoveryPrivateKey: Data, identifierToRemove: String, result: @escaping FlutterResult) {
        guard let client = client else {
            result(FlutterError(code: "CLIENT_NOT_INITIALIZED", message: "XMTP client has not been initialized", details: nil))
            return
        }

        Task {
            do {
                let recoveryAccount = try PrivateKey(recoveryPrivateKey)
                let identityToRemove = PublicIdentity(kind: .ethereum, identifier: identifierToRemove)
                try await client.removeAccount(recoveryAccount: recoveryAccount, identityToRemove: identityToRemove)

                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "REMOVE_ACCOUNT_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func staticRevokeInstallations(signerPrivateKey: Data, inboxId: String, installationIds: [String], result: @escaping FlutterResult) {
        Task {
            do {
                let signer = try PrivateKey(signerPrivateKey)
                let api = ClientOptions.Api(env: .production, isSecure: true)
                try await XMTP.Client.revokeInstallations(
                    api: api,
                    signingKey: signer,
                    inboxId: inboxId,
                    installationIds: installationIds
                )

                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "STATIC_REVOKE_INSTALLATIONS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func staticInboxStatesForInboxIds(inboxIds: [String], result: @escaping FlutterResult) {
        Task {
            do {
                let api = ClientOptions.Api(env: .production, isSecure: true)
                let inboxStates = try await XMTP.Client.inboxStatesForInboxIds(inboxIds: inboxIds, api: api)

                let statesList = inboxStates.map { state -> [String: Any] in
                    [
                        "inboxId": state.inboxId,
                        "identities": state.identities.map { identity in
                            [
                                "identifier": identity.identifier,
                                "kind": identity.kind == .ethereum ? "ethereum" : "passkey"
                            ]
                        },
                        "installations": state.installations.map { installation in
                            [
                                "id": installation.id,
                                "createdAt": installation.createdAt.map { Int64($0.timeIntervalSince1970 * 1000) } as Any
                            ]
                        },
                        "recoveryIdentity": [
                            "identifier": state.recoveryIdentity.identifier,
                            "kind": state.recoveryIdentity.kind == .ethereum ? "ethereum" : "passkey"
                        ]
                    ]
                }

                DispatchQueue.main.async {
                    result(statesList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "STATIC_INBOX_STATES_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func staticGetInboxIdForAddress(address: String, environment: String, result: @escaping FlutterResult) {
        Task {
            do {
                let env = resolveEnvironment(environment)
                let api = ClientOptions.Api(env: env, isSecure: env != .local)
                let publicIdentity = PublicIdentity(kind: .ethereum, identifier: address)
                let inboxId = try await XMTP.Client.getOrCreateInboxId(api: api, publicIdentity: publicIdentity)
                DispatchQueue.main.async {
                    result(inboxId)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "STATIC_GET_INBOX_ID_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func staticDeleteLocalDatabase(inboxId: String, environment: String, result: @escaping FlutterResult) {
        Task {
            do {
                let env = resolveEnvironment(environment)
                let alias = "xmtp-\(env.rawValue)-\(inboxId).db3"
                let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let dbURL = docsDir.appendingPathComponent(alias)
                let fm = FileManager.default
                if fm.fileExists(atPath: dbURL.path) {
                    try fm.removeItem(at: dbURL)
                }
                // Also clean up WAL/SHM if present
                let walURL = dbURL.appendingPathExtension("wal")
                if fm.fileExists(atPath: walURL.path) {
                    try fm.removeItem(at: walURL)
                }
                let shmURL = dbURL.appendingPathExtension("shm")
                if fm.fileExists(atPath: shmURL.path) {
                    try fm.removeItem(at: shmURL)
                }
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "STATIC_DELETE_DB_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
}

// MARK: - Extensions
extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []
        for element in self {
            let transformed = try await transform(element)
            result.append(transformed)
        }
        return result
    }
}