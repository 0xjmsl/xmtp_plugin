package io.xmtp.xmtp_plugin

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import org.xmtp.android.library.Client
import org.xmtp.android.library.Group
import org.xmtp.android.library.Conversation
import org.xmtp.android.library.ClientOptions
import org.xmtp.android.library.XMTPEnvironment
import org.xmtp.android.library.ConsentState
import org.xmtp.android.library.ConsentRecord
import org.xmtp.android.library.libxmtp.PermissionLevel
import org.xmtp.android.library.libxmtp.PublicIdentity
import org.xmtp.android.library.libxmtp.IdentityKind
import org.xmtp.proto.message.api.v1.MessageApiOuterClass.Envelope
import org.xmtp.proto.message.contents.Content.ContentTypeId
import org.xmtp.android.library.codecs.Attachment
import org.xmtp.android.library.codecs.AttachmentCodec
import org.xmtp.android.library.codecs.RemoteAttachment
import org.xmtp.android.library.codecs.RemoteAttachmentCodec
import org.xmtp.android.library.codecs.ContentTypeIdBuilder
import org.xmtp.android.library.codecs.EncodedContent
// import org.xmtp.android.library.libxmtp.Message
import org.xmtp.android.library.messages.PrivateKeyBuilder
import java.security.SecureRandom
import java.util.Date
import java.net.URL
// Remove the duplicate ByteString imports and use only the protobuf one
import com.google.protobuf.ByteString
import com.google.protobuf.kotlin.toByteString

data class ContentType(
    val authorityId: String,
    val typeId: String,
    val versionMajor: Int
)

class XmtpPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private var client: Client? = null
  private val scope = CoroutineScope(Dispatchers.IO)
  private lateinit var context: Context  // Add this

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "xmtp_plugin")
    context = flutterPluginBinding.applicationContext  // Store context here
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "generatePrivateKey" -> {
        generatePrivateKey(result)
      }
      "initializeClient" -> {
        val key = call.argument<ByteArray>("privateKey")
        val dbKey = call.argument<ByteArray>("dbKey")
        val environment = call.argument<String>("environment") ?: "production"
        if (key != null && dbKey != null) {
          initializeClient(key, dbKey, environment, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Key and dbKey are required", null)
        }
      }
      "getClientAddress" -> {
        getClientAddress(result)
      }
      "getClientInboxId" -> {
        getClientInboxId(result)
      }
      "sendMessage" -> {
                    val recipientAddress = call.argument<String>("recipientAddress")
                    val message = call.argument<Map<String, Any>>("message")  // Changed to ByteArray
                    val contentType = getContentType(call)
                    
                    if (recipientAddress != null && message != null && contentType != null) {
                        sendMessage(recipientAddress, message, contentType, result)
                    } else {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Recipient address, message and content type are required",
                            null
                        )
                    }
                }
      "sendMessageByInboxId" -> {
                    val recipientInboxId = call.argument<String>("recipientInboxId")
                    val message = call.argument<Map<String, Any>>("message")  // Changed to ByteArray
                    val contentType = getContentType(call)
                    
                    if (recipientInboxId != null && message != null && contentType != null) {
                        sendMessageByInboxId(recipientInboxId, message, contentType, result)
                    } else {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "recipientInboxId, message and content type are required",
                            null
                        )
                    }
                }
      "sendGroupMessage" -> {
          val topic = call.argument<String>("topic")
          val message = call.argument<Map<String, Any>>("message")  // Changed to ByteArray
          val contentType = getContentType(call)
          
          if (topic != null && message != null && contentType != null) {
              sendGroupMessage(topic, message, contentType, result)
          } else {
              result.error(
                  "INVALID_ARGUMENTS",
                  "Topic, message and content type are required",
                  null
              )
          }
      }
      "subscribeToAllMessages" -> {
        subscribeToAllMessages(result)
      }
      "getConversationConsentState" -> {
        val topic = call.argument<String>("topic")
        if (topic != null) {
          getConversationConsentState(topic, result)
        } else {
          result.error("INVALID_ARGUMENTS", "topic is required", null)
        }
      }
      "setConversationConsentState" -> {
        val topic = call.argument<String>("topic")
        val state = call.argument<String>("state")
        if (topic != null && state != null) {
          setConversationConsentState(topic, state, result)
        } else {
          result.error("INVALID_ARGUMENTS", "topic and state are required", null)
        }
      }
      "getInboxConsentState" -> {
        val inboxId = call.argument<String>("inboxId")
        if (inboxId != null) {
          getInboxConsentState(inboxId, result)
        } else {
          result.error("INVALID_ARGUMENTS", "inboxId is required", null)
        }
      }
      "setInboxConsentState" -> {
        val inboxId = call.argument<String>("inboxId")
        val state = call.argument<String>("state")
        if (inboxId != null && state != null) {
          setInboxConsentState(inboxId, state, result)
        } else {
          result.error("INVALID_ARGUMENTS", "inboxId and state are required", null)
        }
      }
      "syncConsentPreferences" -> {
        syncConsentPreferences(result)
      }
      "sendSyncRequest" -> {
        sendSyncRequest(result)
      }
      "syncAll" -> {
        val consentStates = call.argument<List<String>>("consentStates")
        syncAll(consentStates, result)
      }
      "syncConversation" -> {
        val topic = call.argument<String>("topic")
        if (topic != null) {
          syncConversation(topic, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic is required", null)
        }
      }
      "listDms" -> {
        val consentState = call.argument<String>("consentState")
        listDms(consentState, result)
      }
      "listGroups" -> {
        val consentState = call.argument<String>("consentState")
        listGroups(consentState, result)
      }
      "newGroup" -> {
        val inboxIds = call.argument<List<String>>("inboxIds")
        val options = call.argument<Map<String, String>>("options")

        if (inboxIds == null) {
          result.error("INVALID_ARGUMENTS", "inboxIds list is required", null)
          return
        }

        if (options == null) {
          result.error("INVALID_ARGUMENTS", "Options map is required", null)
          return
        }

        try {
          // Convert the Map<String, String> to GroupOptions
          val groupOptions = GroupOptions(
            name = options["name"],
            description = options["description"],
            imageUrl = options["imageUrl"],
            pinnedFrameUrl = options["pinnedFrameUrl"]
          )

          newGroup(inboxIds, groupOptions, result)
        } catch (e: Exception) {
          result.error("INVALID_ARGUMENTS", "Error processing arguments: ${e.message}", null)
        }
      }
      // In onMethodCall block:
      "listGroupMembers" -> {
        val topic = call.argument<String>("topic")
        if (topic != null) {
          listGroupMembers(topic, result)
        } else {
          result.error("INVALID_ARGUMENTS", "topic is required", null)
        }
      }
      "listGroupAdmins" -> {
        val topic = call.argument<String>("topic")
        if (topic != null) {
          listGroupAdmins(topic, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic is required", null)
        }
      }
      "listGroupSuperAdmins" -> {
        val topic = call.argument<String>("topic")
        if (topic != null) {
          listGroupSuperAdmins(topic, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic is required", null)
        }
      }
      "addGroupMembers" -> {
        val topic = call.argument<String>("topic")
        val inboxIds = call.argument<List<String>>("inboxIds")
        if (topic != null && inboxIds != null) {
          addGroupMembers(topic, inboxIds, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic and inboxIds are required", null)
        }
      }
      "removeGroupMembers" -> {
        val topic = call.argument<String>("topic")
        val inboxIds = call.argument<List<String>>("inboxIds")
        if (topic != null && inboxIds != null) {
          removeGroupMembers(topic, inboxIds, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic and inboxIds are required", null)
        }
      }
      "addGroupAdmin" -> {
        val topic = call.argument<String>("topic")
        val inboxId = call.argument<String>("inboxId")
        if (topic != null && inboxId != null) {
          addGroupAdmin(topic, inboxId, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic and inboxId are required", null)
        }
      }
      "removeGroupAdmin" -> {
        val topic = call.argument<String>("topic")
        val inboxId = call.argument<String>("inboxId")
        if (topic != null && inboxId != null) {
          removeGroupAdmin(topic, inboxId, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic and inboxId are required", null)
        }
      }
      "addGroupSuperAdmin" -> {
        val topic = call.argument<String>("topic")
        val inboxId = call.argument<String>("inboxId")
        if (topic != null && inboxId != null) {
          addGroupSuperAdmin(topic, inboxId, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic and inboxId are required", null)
        }
      }
      "removeGroupSuperAdmin" -> {
        val topic = call.argument<String>("topic")
        val inboxId = call.argument<String>("inboxId")
        if (topic != null && inboxId != null) {
          removeGroupSuperAdmin(topic, inboxId, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic and inboxId are required", null)
        }
      }
      "updateGroup" -> {
        val topic = call.argument<String>("topic")
        val updates = call.argument<Map<String, String>>("updates")
        if (topic != null && updates != null) {
          updateGroup(topic, updates, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic and updates are required", null)
        }
      }
      "getGroupMemberRole" -> {
        val topic = call.argument<String>("topic")
        val inboxId = call.argument<String>("inboxId")
        if (topic != null && inboxId != null) {
          getGroupMemberRole(topic, inboxId, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic and inboxId are required", null)
        }
      }
      "canMessageByAddress" -> {
              val address = call.argument<String>("address")
              if (address != null) {
                canMessage(address, result)
              } else {
                result.error("INVALID_ARGUMENTS", "Address is required", null)
              }
            }
      "canMessageByInboxId" -> {
              val inboxId = call.argument<String>("inboxId")
              if (inboxId != null) {
                canMessageByInboxId(inboxId, result)
              } else {
                result.error("INVALID_ARGUMENTS", "Inbox ID is required", null)
              }
            }
      "findOrCreateDMWithInboxId" -> {
              val inboxId = call.argument<String>("inboxId")
              if (inboxId != null) {
                findOrCreateDMWithInboxId(inboxId, result)
              } else {
                result.error("INVALID_ARGUMENTS", "inboxId is required", null)
              }
            }
      "findDmByInboxId" -> {
              val inboxId = call.argument<String>("inboxId")
              if (inboxId != null) {
                findDmByInboxId(inboxId, result)
              } else {
                result.error("INVALID_ARGUMENTS", "inboxId is required", null)
              }
            }
      "inboxIdFromAddress" -> {
              val address = call.argument<String>("address")
              if (address != null) {
                inboxIdFromAddress(address, result)
              } else {
                result.error("INVALID_ARGUMENTS", "Address is required", null)
              }
            }
      "getMessagesAfterDate" -> {
        val peerAddress = call.argument<String>("peerAddress")
        val fromDate = call.argument<Long>("fromDate")
        if (peerAddress != null && fromDate != null) {
          getMessagesAfterDate(peerAddress, fromDate, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Peer address and from date are required", null)
        }
      }
      "getMessagesAfterDateByTopic" -> {
        val topic = call.argument<String>("topic")
        val fromDate = call.argument<Long>("fromDate")
        if (topic != null && fromDate != null) {
          getMessagesAfterDateByTopic(topic, fromDate, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Peer address and from date are required", null)
        }
      }
      "loadRemoteAttachment" -> {
          // IMPORTANT: Don't return until async work is done
          // Use a blocking approach to ensure Flutter waits for the result
          Thread {
              try {
                  val args = call.arguments as Map<*, *>
                  println("Android RemoteAttachment Debug - Raw args: $args")

                  // Parse all the arguments
                  val urlString = args["url"] as String
                  val url = URL(urlString)
                  val contentDigest = args["contentDigest"] as String
                  val secretList = args["secret"] as List<Int>
                  val secretBytes = secretList.map { it.toByte() }.toByteArray()
                  val secretByteString = secretBytes.toByteString()
                  val saltList = args["salt"] as List<Int>
                  val saltBytes = saltList.map { it.toByte() }.toByteArray()
                  val saltByteString = saltBytes.toByteString()
                  val nonceList = args["nonce"] as List<Int>
                  val nonceBytes = nonceList.map { it.toByte() }.toByteArray()
                  val nonceByteString = nonceBytes.toByteString()
                  val scheme = args["scheme"] as String
                  val contentLength = args["contentLength"] as Int?
                  val filename = args["filename"] as String?

                  val remoteAttachment = RemoteAttachment(
                      url = url,
                      contentDigest = contentDigest,
                      secret = secretByteString,
                      salt = saltByteString,
                      nonce = nonceByteString,
                      scheme = scheme,
                      contentLength = contentLength,
                      filename = filename
                  )

                  println("Android RemoteAttachment Debug - RemoteAttachment created, attempting to load")
                  // This call blocks until complete (synchronous)
                  val loadedContent = remoteAttachment.load() as Attachment?
                  println("Android RemoteAttachment Debug - RemoteAttachment loaded")

                  // Convert the Attachment to a map that Flutter can understand
                  val attachmentMap = mapOf(
                      "filename" to loadedContent?.filename,
                      "mimeType" to loadedContent?.mimeType,
                      "data" to loadedContent?.data?.toByteArray()
                  )

                  println("Android RemoteAttachment Debug - Content loaded successfully, size: ${loadedContent?.data?.size()}")

                  // Send result on main thread
                  Handler(Looper.getMainLooper()).post {
                      result.success(attachmentMap!!)
                  }

              } catch (e: Exception) {
                  println("Android RemoteAttachment Debug - Error occurred: ${e.message}")
                  println("Android RemoteAttachment Debug - Stack trace: ${e.stackTraceToString()}")

                  // Send error on main thread
                  Handler(Looper.getMainLooper()).post {
                      result.error("LOAD_ERROR", e.message, null)
                  }
              }
          }.start()
      }
      "conversationTopicFromAddress" -> { // Ensure this string matches the Dart side
        val peerAddress = call.argument<String>("peerAddress")
        if (peerAddress != null) {
            conversationTopicFromAddress(peerAddress, result)
        } else {
            result.error("INVALID_ARGUMENTS", "peerAddress is required for conversationTopicFromAddress", null)
        }
    }
      "inboxStatesForInboxIds" -> {
        val inboxIds = call.argument<List<String>>("inboxIds")
        val refreshFromNetwork = call.argument<Boolean>("refreshFromNetwork") ?: false  // Changed default to false
        if (inboxIds != null) {
          inboxStatesForInboxIds(inboxIds, refreshFromNetwork, result)
        } else {
          result.error("INVALID_ARGUMENTS", "inboxIds are required", null)
        }
      }
      "syncAll" -> {
        val consentStates = call.argument<List<String>>("consentStates") ?: listOf("allowed")
        syncAll(consentStates, result)
      }
      "syncConversation" -> {
        val topic = call.argument<String>("topic")
        if (topic != null) {
          syncConversation(topic, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Topic is required", null)
        }
      }
      // ============================================================================
      // INBOX MANAGEMENT METHODS
      // ============================================================================
      "getInstallationId" -> {
        getInstallationId(result)
      }
      "inboxState" -> {
        val refreshFromNetwork = call.argument<Boolean>("refreshFromNetwork") ?: false
        inboxState(refreshFromNetwork, result)
      }
      "revokeInstallations" -> {
        val signerPrivateKey = call.argument<ByteArray>("signerPrivateKey")
        val installationIds = call.argument<List<String>>("installationIds")
        if (signerPrivateKey != null && installationIds != null) {
          revokeInstallations(signerPrivateKey, installationIds, result)
        } else {
          result.error("INVALID_ARGUMENTS", "signerPrivateKey and installationIds are required", null)
        }
      }
      "revokeAllOtherInstallations" -> {
        val signerPrivateKey = call.argument<ByteArray>("signerPrivateKey")
        if (signerPrivateKey != null) {
          revokeAllOtherInstallations(signerPrivateKey, result)
        } else {
          result.error("INVALID_ARGUMENTS", "signerPrivateKey is required", null)
        }
      }
      "addAccount" -> {
        val newAccountPrivateKey = call.argument<ByteArray>("newAccountPrivateKey")
        val allowReassignInboxId = call.argument<Boolean>("allowReassignInboxId") ?: false
        if (newAccountPrivateKey != null) {
          addAccount(newAccountPrivateKey, allowReassignInboxId, result)
        } else {
          result.error("INVALID_ARGUMENTS", "newAccountPrivateKey is required", null)
        }
      }
      "removeAccount" -> {
        val recoveryPrivateKey = call.argument<ByteArray>("recoveryPrivateKey")
        val identifierToRemove = call.argument<String>("identifierToRemove")
        if (recoveryPrivateKey != null && identifierToRemove != null) {
          removeAccount(recoveryPrivateKey, identifierToRemove, result)
        } else {
          result.error("INVALID_ARGUMENTS", "recoveryPrivateKey and identifierToRemove are required", null)
        }
      }
      "staticRevokeInstallations" -> {
        val signerPrivateKey = call.argument<ByteArray>("signerPrivateKey")
        val inboxId = call.argument<String>("inboxId")
        val installationIds = call.argument<List<String>>("installationIds")
        if (signerPrivateKey != null && inboxId != null && installationIds != null) {
          staticRevokeInstallations(signerPrivateKey, inboxId, installationIds, result)
        } else {
          result.error("INVALID_ARGUMENTS", "signerPrivateKey, inboxId and installationIds are required", null)
        }
      }
      "staticInboxStatesForInboxIds" -> {
        val inboxIds = call.argument<List<String>>("inboxIds")
        if (inboxIds != null) {
          staticInboxStatesForInboxIds(inboxIds, result)
        } else {
          result.error("INVALID_ARGUMENTS", "inboxIds is required", null)
        }
      }
      "staticGetInboxIdForAddress" -> {
        val address = call.argument<String>("address")
        val environment = call.argument<String>("environment") ?: "production"
        if (address != null) {
          staticGetInboxIdForAddress(address, environment, result)
        } else {
          result.error("INVALID_ARGUMENTS", "address is required", null)
        }
      }
      "staticDeleteLocalDatabase" -> {
        val inboxId = call.argument<String>("inboxId")
        val environment = call.argument<String>("environment") ?: "production"
        if (inboxId != null) {
          staticDeleteLocalDatabase(inboxId, environment, result)
        } else {
          result.error("INVALID_ARGUMENTS", "inboxId is required", null)
        }
      }
      "changeRecoveryIdentifier" -> {
        // Not supported on Android - only on web/JS
        result.error("UNSUPPORTED_PLATFORM", "changeRecoveryIdentifier is only supported on web platforms", null)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun getContentType(call: MethodCall): ContentType? {
          val authorityId = call.argument<String>("authorityId")
          val typeId = call.argument<String>("typeId")
          val versionMajor = call.argument<Int>("versionMajor")

          return if (authorityId != null && typeId != null && versionMajor != null) {
              ContentType(authorityId, typeId, versionMajor)
          } else {
              null
          }
      }

  private fun generatePrivateKey(result: Result) {
    val privateKeyBuilder = PrivateKeyBuilder()
    val privateKey = privateKeyBuilder.getPrivateKey()
    val privateKeyBytes = privateKey.secp256K1.bytes.toByteArray()
    result.success(privateKeyBytes)
  }

  private fun resolveEnvironment(env: String): XMTPEnvironment {
    return when (env.lowercase()) {
      "dev" -> XMTPEnvironment.DEV
      "local" -> XMTPEnvironment.LOCAL
      else -> XMTPEnvironment.PRODUCTION
    }
  }

  private fun initializeClient(privateKey: ByteArray, dbKey: ByteArray, environment: String, result: Result) {

    scope.launch {
      try {
        val wallet =  PrivateKeyBuilder(PrivateKeyBuilder.buildFromPrivateKeyData(privateKey))

        val xmtpEnv = resolveEnvironment(environment)
        val options = ClientOptions(
          api = ClientOptions.Api(xmtpEnv, true),
          appContext = context,
          dbEncryptionKey = dbKey,
        )
        client = null
        client = Client.create(account = wallet, options = options)
        val clientIdentity = wallet.publicIdentity

        Client.build(clientIdentity, options = options)
        Client.register(codec = RemoteAttachmentCodec())
        Client.register(codec = AttachmentCodec())
        result.success(client?.publicIdentity?.identifier)
      } catch (e: Exception) {
        result.error("CLIENT_INITIALIZATION_FAILED", e.message, null)
      }
    }
  }

  private fun getClientAddress(result: Result) {
    val address = client?.publicIdentity?.identifier
    if (address != null) {
      result.success(address)
    } else {
      result.error("CLIENT_NOT_INITIALIZED", "XMTP client has not been initialized", null)
    }
  }

    private fun getClientInboxId(result: Result) {
    val inboxId = client?.inboxId
    if (inboxId != null) {
      result.success(inboxId)
    } else {
      result.error("CLIENT_NOT_INITIALIZED", "XMTP client has not been initialized", null)
    }
  }

  private fun sendMessage(
      recipientAddress: String,
      encodedMessage: Map<String, Any>,  // Changed from ByteArray to Map
      contentType: ContentType,
      result: Result
  ) {
      scope.launch {
          try {
              val publicIdentity = PublicIdentity(IdentityKind.ETHEREUM, recipientAddress)
              val conversation = client?.conversations?.findOrCreateDmWithIdentity(publicIdentity)
              println("Android Conversation: $conversation")
              
              // Extract content and parameters from the encoded message
              val content = (encodedMessage["content"] as? ByteArray) 
                  ?: throw Exception("Content must be ByteArray")
              val parameters = (encodedMessage["parameters"] as? Map<String, String>) ?: mapOf()
              
              // Create encoded content with the specified content type and parameters
              val encodedContent = EncodedContent.newBuilder()
                  .setType(
                      ContentTypeId.newBuilder()
                          .setAuthorityId(contentType.authorityId)
                          .setTypeId(contentType.typeId)
                          .setVersionMajor(contentType.versionMajor)
                          .build()
                  )
                  .putAllParameters(parameters)  // Add all parameters from the encoded message
                  .setContent(ByteString.copyFrom(content))
                  .build()

              val sendResult = conversation?.send(encodedContent)
              println("Android Send result: $sendResult")

              result.success(sendResult)
          } catch (e: Exception) {
              result.error("MESSAGE_SEND_FAILED", e.message, null)
          }
      }
  }

  private fun sendMessageByInboxId(
      recipientInboxId: String,
      encodedMessage: Map<String, Any>,  // Changed from ByteArray to Map
      contentType: ContentType,
      result: Result
  ) {
      scope.launch {
          try {

              val conversation = client?.conversations?.findDmByInboxId(recipientInboxId)
              println("Android Conversation: $conversation")
              
              // Extract content and parameters from the encoded message
              val content = (encodedMessage["content"] as? ByteArray) 
                  ?: throw Exception("Content must be ByteArray")
              val parameters = (encodedMessage["parameters"] as? Map<String, String>) ?: mapOf()
              
              // Create encoded content with the specified content type and parameters
              val encodedContent = EncodedContent.newBuilder()
                  .setType(
                      ContentTypeId.newBuilder()
                          .setAuthorityId(contentType.authorityId)
                          .setTypeId(contentType.typeId)
                          .setVersionMajor(contentType.versionMajor)
                          .build()
                  )
                  .putAllParameters(parameters)  // Add all parameters from the encoded message
                  .setContent(ByteString.copyFrom(content))
                  .build()

              val sendResult = conversation?.send(encodedContent)
              println("Android Send result: $sendResult")

              result.success(sendResult)
          } catch (e: Exception) {
              result.error("MESSAGE_SEND_FAILED", e.message, null)
          }
      }
  }

  private fun sendGroupMessage(
      topic: String,
      encodedMessage: Map<String, Any>,  // Changed from ByteArray to Map
      contentType: ContentType,
      result: Result
  ) {
      scope.launch {
          try {
              val conversation = client?.conversations?.findConversationByTopic(topic)
              println("Android Conversation: $conversation")
              
              // Extract content and parameters from the encoded message
              val content = (encodedMessage["content"] as? ByteArray) 
                  ?: throw Exception("Content must be ByteArray")
              val parameters = (encodedMessage["parameters"] as? Map<String, String>) ?: mapOf()
              println("Android Content: $content")
              println("Android Parameters: $parameters")
              // Create encoded content with the specified content type and parameters
              val encodedContent = EncodedContent.newBuilder()
                  .setType(
                      ContentTypeId.newBuilder()
                          .setAuthorityId(contentType.authorityId)
                          .setTypeId(contentType.typeId)
                          .setVersionMajor(contentType.versionMajor)
                          .setVersionMinor(0)
                          .build()
                  )
                  .putAllParameters(parameters)  // Add all parameters from the encoded message
                  .setContent(ByteString.copyFrom(content))
                  .build()
              
              val sendResult = conversation?.send(encodedContent)
              println("Android Send result: $sendResult")

              result.success(sendResult)
          } catch (e: Exception) {
              result.error("GROUP_MESSAGE_SEND_FAILED", e.message, null)
          }
      }
  }

  private fun subscribeToAllMessages(result: Result) {
      scope.launch {
          try {
              println("Android Subscribing to all messages")
              client?.conversations?.streamAllMessages()?.collect { message ->
                  println("Android received message from: $message")
                  val conversations = client?.conversations
                  val messageMap = mapOf(
                      "id" to message.id,
                      "body" to message.body,
                      "sent" to message.sentAt.time,
                      "conversationTopic" to message.topic,
                      "senderInboxId" to message.senderInboxId,
                      "encodedContent" to message.encodedContent.toByteArray(),
                      "members" to conversations?.findConversationByTopic(message.topic)?.members()?.map { member ->
                          mapOf(
                              "inboxId" to member.inboxId,
                              "addresses" to member.identities.first().identifier
                          )
                      }
                  )
                  println("Android Message map: $messageMap")
                  scope.launch(Dispatchers.Main) {
                      channel.invokeMethod("onMessageReceived", messageMap)
                  }
              }
              result.success(null)
          } catch (e: Exception) {
              println("Android Subscribed to all messages ERROR")
              result.error("SUBSCRIPTION_FAILED", e.message, null)
          }
      }
  }

  private fun getMessagesAfterDate(peerAddress: String, fromDate: Long, result: Result) {
      scope.launch {
          try {
              println("Android Recovering messages for: $peerAddress")
              client?.conversations?.syncAllConversations()
              val conversation = client?.conversations?.findOrCreateDm(peerAddress)
              val messages = conversation?.messages(
                  beforeNs = null,
                  afterNs = fromDate * 1_000_000,
                  limit = null
              )
              val messageList = messages?.mapNotNull { message ->
                  val messageMap = mapOf(
                      "id" to message.id,
                      "body" to message.body,
                      "sent" to message.sentAt.time,
                      "conversationTopic" to message.topic,
                      "senderInboxId" to message.senderInboxId,
                      "encodedContent" to message.encodedContent.toByteArray(),
                      "members" to conversation?.members()?.map { member ->
                          mapOf(
                              "inboxId" to member.inboxId,
                              "addresses" to member.identities.first().identifier
                          )
                      }
                  )
                  messageMap
              }
              println("Messages in android: $messageList")
              result.success(messageList)
          } catch (e: Exception) {
              result.error("GET_MESSAGES_FAILED", e.message, null)
          }
      }
  }

  private fun getMessagesAfterDateByTopic(topic: String, fromDate: Long, result: Result) {
      scope.launch {
          try {
              println("Android Recovering messages for topic: $topic")
              client?.conversations?.syncAllConversations()
              val conversation = client?.conversations?.findConversationByTopic(topic)
              val messages = conversation?.messages(
                  beforeNs = null,
                  afterNs = fromDate * 1_000_000,
                  limit = null
              )
              val messageList = messages?.mapNotNull { message ->

                  val messageMap = mapOf(
                      "id" to message.id,
                      "body" to message.body,
                      "sent" to message.sentAt.time,
                      "conversationTopic" to message.topic,
                      "senderInboxId" to message.senderInboxId,
                      "encodedContent" to message.encodedContent.toByteArray(),
                      "members" to conversation?.members()?.map { member ->
                          mapOf(
                              "inboxId" to member.inboxId,
                              "addresses" to member.identities.first().identifier
                          )
                      }
                  )
                  messageMap
              }
              println("Messages in android: $messageList")
              result.success(messageList)
          } catch (e: Exception) {
              result.error("GET_MESSAGES_FAILED", e.message, null)
          }
      }
  }

  // Consent management methods
  private fun getConversationConsentState(topic: String, result: Result) {
    scope.launch {
      try {
        val conversation = client?.conversations?.findConversationByTopic(topic)
        val state = conversation?.consentState() ?: ConsentState.UNKNOWN
        result.success(state.name.lowercase())
      } catch (e: Exception) {
        result.error("GET_CONSENT_STATE_FAILED", e.message, null)
      }
    }
  }

  private fun setConversationConsentState(topic: String, state: String, result: Result) {
    scope.launch {
      try {
        val conversation = client?.conversations?.findConversationByTopic(topic)
        if (conversation == null) {
          result.error("CONVERSATION_NOT_FOUND", "Conversation with topic $topic not found", null)
          return@launch
        }

        val consentState = when(state.lowercase()) {
          "allowed" -> ConsentState.ALLOWED
          "denied" -> ConsentState.DENIED
          "unknown" -> ConsentState.UNKNOWN
          else -> {
            result.error("INVALID_CONSENT_STATE", "Invalid consent state: $state", null)
            return@launch
          }
        }

        conversation.updateConsentState(consentState)
        result.success(true)
      } catch (e: Exception) {
        result.error("SET_CONSENT_STATE_FAILED", e.message, null)
      }
    }
  }

  private fun getInboxConsentState(inboxId: String, result: Result) {
    scope.launch {
      try {
        val state = client?.preferences?.inboxIdState(inboxId) ?: ConsentState.UNKNOWN
        result.success(state.name.lowercase())
      } catch (e: Exception) {
        result.error("GET_INBOX_CONSENT_STATE_FAILED", e.message, null)
      }
    }
  }

  private fun setInboxConsentState(inboxId: String, state: String, result: Result) {
    scope.launch {
      try {
        val consentState = when(state.lowercase()) {
          "allowed" -> ConsentState.ALLOWED
          "denied" -> ConsentState.DENIED
          "unknown" -> ConsentState.UNKNOWN
          else -> {
            result.error("INVALID_CONSENT_STATE", "Invalid consent state: $state", null)
            return@launch
          }
        }

        val record = ConsentRecord.inboxId(inboxId, consentState)
        client?.preferences?.setConsentState(listOf(record))
        result.success(true)
      } catch (e: Exception) {
        result.error("SET_INBOX_CONSENT_STATE_FAILED", e.message, null)
      }
    }
  }

  private fun syncConsentPreferences(result: Result) {
    scope.launch {
      try {
        client?.preferences?.sync()
        result.success(true)
      } catch (e: Exception) {
        result.error("SYNC_CONSENT_PREFERENCES_FAILED", e.message, null)
      }
    }
  }

  @Suppress("DEPRECATION")
  private fun sendSyncRequest(result: Result) {
    scope.launch {
      try {
        client?.preferences?.syncConsent()
        result.success(true)
      } catch (e: Exception) {
        result.error("SEND_SYNC_REQUEST_FAILED", e.message, null)
      }
    }
  }
  // Do not use this function
  // private fun listConversations(result: Result) {
  //   scope.launch {
  //     try {
  //       // client?.conversations?.sync()
  //       client?.conversations?.syncAllConversations()
  //       val conversations = client?.conversations?.listDms()

  //       println("Android Conversations lists form DMs: $conversations")
  //       val conversationList = conversations?.map { conversation ->
  //         mapOf(
  //           "id" to conversation.id,
  //           "topic" to conversation.topic,
  //           "createdAt" to conversation.createdAt.time,
  //           "peerInboxId" to conversation.peerInboxId,
  //           "members" to conversations?.findConversationByTopic(message.topic)?.members()?.map { member ->
  //               mapOf(
  //                   "inboxId" to member.inboxId,
  //                   "addresses" to member.identities.first().identifier
  //               )
  //           }
  //         )
  //       }

  //       result.success(conversationList)
  //     } catch (e: Exception) {
  //       result.error("LIST_CONVERSATIONS_FAILED", e.message, null)
  //     }
  //   }
  // }

  private fun syncAll(consentStates: List<String>?, result: Result) {
    scope.launch {
      try {
        // Convert consent state strings to ConsentState list
        val states = consentStates?.mapNotNull { stateStr ->
          when(stateStr.lowercase()) {
            "allowed" -> ConsentState.ALLOWED
            "denied" -> ConsentState.DENIED
            "unknown" -> ConsentState.UNKNOWN
            else -> null
          }
        } ?: listOf(ConsentState.ALLOWED)

        val syncSummary = client?.conversations?.syncAllConversations(states)

        result.success(mapOf(
          "numGroupsSynced" to (syncSummary?.numSynced?.toLong() ?: 0L)
        ))
      } catch (e: Exception) {
        result.error("SYNC_ALL_FAILED", e.message, null)
      }
    }
  }

  private fun syncConversation(topic: String, result: Result) {
    scope.launch {
      try {
        val conversation = client?.conversations?.findConversationByTopic(topic)
        conversation?.sync()
        result.success(null)
      } catch (e: Exception) {
        result.error("SYNC_CONVERSATION_FAILED", e.message, null)
      }
    }
  }

  private fun listDms(consentState: String?, result: Result) {
    scope.launch {
      try {
        // Sync removed - now local-only read. Call syncAll() explicitly when needed.

        // Convert consent state string to ConsentState list
        val consentStates = consentState?.let {
          when(it.lowercase()) {
            "allowed" -> listOf(ConsentState.ALLOWED)
            "denied" -> listOf(ConsentState.DENIED)
            "unknown" -> listOf(ConsentState.UNKNOWN)
            else -> null
          }
        }

        val conversations = client?.conversations?.listDms(
          consentStates = consentStates
        )

        println("Android Conversations lists form DMs: $conversations")
        val conversationList = conversations?.map { conversation ->
          mapOf(
            "id" to conversation.id,
            "topic" to conversation.topic,
            "createdAt" to conversation.createdAt.time,
            "peerInboxId" to conversation.peerInboxId,
            "members" to conversation?.members()?.map { member ->
                mapOf(
                    "inboxId" to member.inboxId,
                    "addresses" to member.identities.first().identifier
                )
            }
          )
        }

        result.success(conversationList)
      } catch (e: Exception) {
        result.error("LIST_CONVERSATIONS_FAILED", e.message, null)
      }
    }
  }

  private fun listGroups(consentState: String?, result: Result) {
    scope.launch {
      try {
        // Sync removed - now local-only read. Call syncAll() explicitly when needed.

        // Convert consent state string to ConsentState list
        val consentStates = consentState?.let {
          when(it.lowercase()) {
            "allowed" -> listOf(ConsentState.ALLOWED)
            "denied" -> listOf(ConsentState.DENIED)
            "unknown" -> listOf(ConsentState.UNKNOWN)
            else -> null
          }
        }

        val conversations = client?.conversations?.listGroups(
          consentStates = consentStates
        )

        println("Android Conversations lists form Groups: $conversations")
        val conversationList = conversations?.map { conversation ->
          mapOf(
            "id" to conversation.id,
            "topic" to conversation.topic,
            "createdAt" to conversation.createdAt.time,
            "name" to conversation.name,
            "imageUrlSquare" to conversation.imageUrl,
            "description" to conversation.description,
            "members" to conversation?.members()?.map { member ->
                mapOf(
                    "inboxId" to member.inboxId,
                    "addresses" to member.identities.first().identifier
                )
            }
          )
        }

        result.success(conversationList)
      } catch (e: Exception) {
        result.error("LIST_CONVERSATIONS_FAILED", e.message, null)
      }
    }
  }

  private fun inboxIdFromAddress(address: String, result: Result) {
    scope.launch {
      try {
        val publicIdentity = PublicIdentity(IdentityKind.ETHEREUM, address)
        val inboxId = client?.inboxIdFromIdentity(publicIdentity)
        result.success(inboxId)
      } catch (e: Exception) {
        result.error("inboxIDfromAddress_CHECK_FAILED", e.message, null)
      }
    }
  }

  private fun canMessage(address: String, result: Result) {
    scope.launch {
      try {
        val publicIdentity = PublicIdentity(IdentityKind.ETHEREUM, address)
        val canMessageMap = client?.canMessage(listOf(publicIdentity))
        val canMessage = canMessageMap?.get(publicIdentity.identifier)
        result.success(canMessage)
      } catch (e: Exception) {
        result.error("CAN_MESSAGE_CHECK_FAILED", e.message, null)
      }
    }
  }

  private fun canMessageByInboxId(inboxId: String, result: Result) {
    scope.launch {
      try {
        // Use inboxStatesForInboxIds to check if inbox ID exists
        val inboxStates = client?.inboxStatesForInboxIds(true, listOf(inboxId))

        // If we get a state back with matching inbox ID, it exists
        val canMessage = inboxStates?.any { it.inboxId == inboxId } ?: false
        result.success(canMessage)
      } catch (e: Exception) {
        result.error("CAN_MESSAGE_BY_INBOX_ID_FAILED", e.message, null)
      }
    }
  }

  private fun inboxStatesForInboxIds(inboxIds: List<String>, refreshFromNetwork: Boolean, result: Result) {
    scope.launch {
      try {
        val inboxStates = client?.inboxStatesForInboxIds(refreshFromNetwork, inboxIds)
        val statesList = inboxStates?.map { state ->
          mapOf(
            "inboxId" to state.inboxId,
            "identities" to state.identities.map { identity ->
              mapOf(
                "identifier" to identity.identifier,
                "kind" to identity.kind.name.lowercase()
              )
            },
            "installations" to state.installations.map { installation ->
              mapOf(
                "id" to installation.installationId,
                // Note: xmtp-android SDK passes nanoseconds to Date(), so divide by 1M
                "createdAt" to installation.createdAt?.time?.let { it / 1_000_000 }
              )
            },
            "recoveryIdentity" to mapOf(
              "identifier" to state.recoveryPublicIdentity.identifier,
              "kind" to state.recoveryPublicIdentity.kind.name.lowercase()
            )
          )
        } ?: emptyList()
        result.success(statesList)
      } catch (e: Exception) {
        result.error("INBOX_STATES_FAILED", e.message, null)
      }
    }
  }

private fun findOrCreateDMWithInboxId(
    inboxId: String,
    result: Result
) {
    scope.launch {
        try {
            val dm = client?.conversations?.findOrCreateDm(inboxId)
            
            if (dm != null) {
                val dmMap = mapOf(
                    "id" to dm.id,
                    "topic" to dm.topic,
                    "createdAt" to dm.createdAt.time,
                    "peerInboxId" to dm.peerInboxId,
                    "members" to dm.members().map { member ->
                        mapOf(
                            "inboxId" to member.inboxId,
                            "addresses" to member.identities.first().identifier
                        )
                    }
                )
                result.success(dmMap)
            } else {
                result.error("DM_NOT_CREATED", "Failed to create or find DM", null)
            }
        } catch (e: Exception) {
            result.error("FIND_OR_CREATE_DM_FAILED", e.message, null)
        }
    }
}

private fun findDmByInboxId(inboxId: String, result: Result) {
    scope.launch {
        try {
            val dm = client?.conversations?.findDmByInboxId(inboxId)

            if (dm != null) {
                val dmMap = mapOf(
                    "id" to dm.id,
                    "topic" to dm.topic,
                    "createdAt" to dm.createdAt.time,
                    "peerInboxId" to dm.peerInboxId,
                    "members" to dm.members().map { member ->
                        mapOf(
                            "inboxId" to member.inboxId,
                            "addresses" to member.identities.first().identifier
                        )
                    }
                )
                result.success(dmMap)
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            result.error("FIND_DM_BY_INBOX_ID_FAILED", e.message, null)
        }
    }
}

private fun conversationTopicFromAddress(peerAddress: String, result: Result) {
    scope.launch {
        try {
            if (client == null) {
                result.error("CLIENT_NOT_INITIALIZED", "XMTP client has not been initialized", null)
                return@launch
            }
            // Validate peerAddress format if necessary, though the SDK might handle this.
            if (peerAddress.isBlank()) {
                result.error("INVALID_ARGUMENTS", "peerAddress cannot be blank", null)
                return@launch
            }

            val publicIdentity = PublicIdentity(IdentityKind.ETHEREUM, peerAddress)
            val conversation = client!!.conversations.findOrCreateDmWithIdentity(publicIdentity)

            if (conversation != null) {
                // For a DM, conversation.topic directly gives the topic string.
                // This string is derived internally by the SDK as described in the issue:
                // Dm.id -> libXMTPGroup.id().toHex()
                // Dm.topic -> Topic.groupMessage(id).description
                val topicResult = conversation.topic 
                result.success(topicResult)
            } else {
                result.error("CONVERSATION_NOT_FOUND", "Could not find or create DM conversation with address $peerAddress", null)
            }
        } catch (e: IllegalArgumentException) {
            // Catching specific exception for invalid address format if PublicIdentity constructor throws it
            result.error("INVALID_ADDRESS_FORMAT", "Invalid peerAddress format: ${e.message}", e.stackTraceToString())
        } catch (e: Exception) {
            // Generic catch block for other errors
            result.error("CONVERSATION_TOPIC_FAILED", "Failed to get conversation topic for $peerAddress: ${e.message}", e.stackTraceToString())
        }
    }
}

  private fun newGroup(inboxIds: List<String>, options: GroupOptions, result: Result) {
    scope.launch {
      try {

        
        val group = client?.conversations?.newGroup(
          inboxIds = inboxIds,
          groupName = options.name ?: "",
          groupImageUrlSquare = options.imageUrl ?: "",
          groupDescription = options.description ?: ""
          // groupPinnedFrameUrl = options.pinnedFrameUrl ?: ""
        )
        // println("Android Group created pre map: $group")
        if (group != null) {
          val groupMap = mapOf(
            "id" to group.id,
            "topic" to group.topic,
            "createdAt" to group.createdAt.time.toString(),
            "name" to group.name,
            "imageUrlSquare" to group.imageUrl,
            "description" to group.description,
            // "pinnedFrameUrl" to group.pinnedFrameUrl
          )
          println("Android Group created: $groupMap")
          result.success(groupMap)
        } else {
          result.error("GROUP_CREATION_FAILED", "Failed to create group", null)
        }
      } catch (e: Exception) {
        result.error("GROUP_CREATION_FAILED", e.message, null)
      }
    }
  }

  private fun listGroupMembers(topic: String, result: Result) {
      scope.launch {
          try {
              val conversation = client?.conversations?.findConversationByTopic(topic)
              when (conversation) {
                  is Conversation.Group -> {
                      val members = conversation.group.members()?.map { member ->
                          mapOf(
                              "inboxId" to member.inboxId,
                              "address" to member.identities.first().identifier
                          )
                      }
                      println("Android Group members: $members")
                      result.success(members)
                  }
                  else -> {
                      result.error("NOT_A_GROUP", "Conversation is not a group", null)
                  }
              }
          } catch (e: Exception) {
              result.error("LIST_MEMBERS_FAILED", e.message, null)
          }
      }
  }

private fun listGroupAdmins(topic: String, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    val admins = conversation.group.listAdmins().map { adminId ->
                        mapOf("inboxId" to adminId)
                    }
                    result.success(admins)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("LIST_ADMINS_FAILED", e.message, null)
        }
    }
}

private fun listGroupSuperAdmins(topic: String, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    val superAdmins = conversation.group.listSuperAdmins().map { adminId ->
                        mapOf("inboxId" to adminId)
                    }
                    result.success(superAdmins)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("LIST_SUPER_ADMINS_FAILED", e.message, null)
        }
    }
}

private fun addGroupMembers(topic: String, inboxIds: List<String>, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    conversation.group.addMembers(inboxIds)
                    result.success(true)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("ADD_MEMBERS_FAILED", e.message, null)
        }
    }
}

private fun removeGroupMembers(topic: String, inboxIds: List<String>, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    conversation.group.removeMembers(inboxIds)
                    result.success(true)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("REMOVE_MEMBERS_FAILED", e.message, null)
        }
    }
}

private fun addGroupAdmin(topic: String, inboxId: String, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    conversation.group.addAdmin(inboxId)
                    result.success(true)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("ADD_ADMIN_FAILED", e.message, null)
        }
    }
}

private fun removeGroupAdmin(topic: String, inboxId: String, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    conversation.group.removeAdmin(inboxId)
                    result.success(true)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("REMOVE_ADMIN_FAILED", e.message, null)
        }
    }
}

private fun addGroupSuperAdmin(topic: String, inboxId: String, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    conversation.group.addSuperAdmin(inboxId)
                    result.success(true)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("ADD_SUPER_ADMIN_FAILED", e.message, null)
        }
    }
}

private fun removeGroupSuperAdmin(topic: String, inboxId: String, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    conversation.group.removeSuperAdmin(inboxId)
                    result.success(true)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("REMOVE_SUPER_ADMIN_FAILED", e.message, null)
        }
    }
}

private fun updateGroup(topic: String, updates: Map<String, String>, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    updates["name"]?.let { conversation.group.updateName(it) }
                    updates["description"]?.let { conversation.group.updateDescription(it) }
                    updates["imageUrl"]?.let { conversation.group.updateImageUrl(it) }
                    // updates["pinnedFrameUrl"]?.let { conversation.group.updateGroupPinnedFrameUrl(it) }
                    result.success(true)
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("UPDATE_GROUP_FAILED", e.message, null)
        }
    }
}

private fun getGroupMemberRole(topic: String, inboxId: String, result: Result) {
    scope.launch {
        try {
            when (val conversation = client?.conversations?.findConversationByTopic(topic)) {
                is Conversation.Group -> {
                    val isAdmin = conversation.group.isAdmin(inboxId)
                    val isSuperAdmin = conversation.group.isSuperAdmin(inboxId)
                    result.success(mapOf(
                        "isAdmin" to isAdmin,
                        "isSuperAdmin" to isSuperAdmin
                    ))
                }
                else -> {
                    result.error("NOT_A_GROUP", "Conversation is not a group", null)
                }
            }
        } catch (e: Exception) {
            result.error("GET_MEMBER_ROLE_FAILED", e.message, null)
        }
    }
}

  // ============================================================================
  // INBOX MANAGEMENT METHODS
  // ============================================================================

  private fun getInstallationId(result: Result) {
    val installationId = client?.installationId
    if (installationId != null) {
      result.success(installationId)
    } else {
      result.error("CLIENT_NOT_INITIALIZED", "XMTP client has not been initialized", null)
    }
  }

  private fun inboxState(refreshFromNetwork: Boolean, result: Result) {
    scope.launch {
      try {
        val state = client?.inboxState(refreshFromNetwork)
        if (state != null) {
          val stateMap = mapOf(
            "inboxId" to state.inboxId,
            "identities" to state.identities.map { identity ->
              mapOf(
                "identifier" to identity.identifier,
                "kind" to identity.kind.name.lowercase()
              )
            },
            "installations" to state.installations.map { installation ->
              mapOf(
                "id" to installation.installationId,
                // Note: xmtp-android SDK passes nanoseconds to Date(), so divide by 1M
                "createdAt" to installation.createdAt?.time?.let { it / 1_000_000 }
              )
            },
            "recoveryIdentity" to mapOf(
              "identifier" to state.recoveryPublicIdentity.identifier,
              "kind" to state.recoveryPublicIdentity.kind.name.lowercase()
            )
          )
          result.success(stateMap)
        } else {
          result.error("CLIENT_NOT_INITIALIZED", "XMTP client has not been initialized", null)
        }
      } catch (e: Exception) {
        result.error("INBOX_STATE_FAILED", e.message, null)
      }
    }
  }

  private fun revokeInstallations(signerPrivateKey: ByteArray, installationIds: List<String>, result: Result) {
    scope.launch {
      try {
        val signer = PrivateKeyBuilder(PrivateKeyBuilder.buildFromPrivateKeyData(signerPrivateKey))
        client?.revokeInstallations(signer, installationIds)
        result.success(null)
      } catch (e: Exception) {
        result.error("REVOKE_INSTALLATIONS_FAILED", e.message, null)
      }
    }
  }

  private fun revokeAllOtherInstallations(signerPrivateKey: ByteArray, result: Result) {
    scope.launch {
      try {
        val signer = PrivateKeyBuilder(PrivateKeyBuilder.buildFromPrivateKeyData(signerPrivateKey))
        client?.revokeAllOtherInstallations(signer)
        result.success(null)
      } catch (e: Exception) {
        result.error("REVOKE_ALL_OTHER_INSTALLATIONS_FAILED", e.message, null)
      }
    }
  }

  private fun addAccount(newAccountPrivateKey: ByteArray, allowReassignInboxId: Boolean, result: Result) {
    scope.launch {
      try {
        val newAccount = PrivateKeyBuilder(PrivateKeyBuilder.buildFromPrivateKeyData(newAccountPrivateKey))
        client?.addAccount(newAccount, allowReassignInboxId)
        result.success(null)
      } catch (e: Exception) {
        result.error("ADD_ACCOUNT_FAILED", e.message, null)
      }
    }
  }

  private fun removeAccount(recoveryPrivateKey: ByteArray, identifierToRemove: String, result: Result) {
    scope.launch {
      try {
        val recoverAccount = PrivateKeyBuilder(PrivateKeyBuilder.buildFromPrivateKeyData(recoveryPrivateKey))
        val identityToRemove = PublicIdentity(IdentityKind.ETHEREUM, identifierToRemove)
        client?.removeAccount(recoverAccount, identityToRemove)
        result.success(null)
      } catch (e: Exception) {
        result.error("REMOVE_ACCOUNT_FAILED", e.message, null)
      }
    }
  }

  private fun staticRevokeInstallations(signerPrivateKey: ByteArray, inboxId: String, installationIds: List<String>, result: Result) {
    scope.launch {
      try {
        val signer = PrivateKeyBuilder(PrivateKeyBuilder.buildFromPrivateKeyData(signerPrivateKey))
        val api = ClientOptions.Api(XMTPEnvironment.PRODUCTION, true)
        Client.revokeInstallations(
          api = api,
          signingKey = signer,
          inboxId = inboxId,
          installationIds = installationIds
        )
        result.success(null)
      } catch (e: Exception) {
        result.error("STATIC_REVOKE_INSTALLATIONS_FAILED", e.message, null)
      }
    }
  }

  private fun staticInboxStatesForInboxIds(inboxIds: List<String>, result: Result) {
    scope.launch {
      try {
        val api = ClientOptions.Api(XMTPEnvironment.PRODUCTION, true)
        val inboxStates = Client.inboxStatesForInboxIds(inboxIds, api)
        val statesList = inboxStates.map { state ->
          mapOf(
            "inboxId" to state.inboxId,
            "identities" to state.identities.map { identity ->
              mapOf(
                "identifier" to identity.identifier,
                "kind" to identity.kind.name.lowercase()
              )
            },
            "installations" to state.installations.map { installation ->
              mapOf(
                "id" to installation.installationId,
                "createdAt" to installation.createdAt?.time?.let { it / 1_000_000 }
              )
            },
            "recoveryIdentity" to mapOf(
              "identifier" to state.recoveryPublicIdentity.identifier,
              "kind" to state.recoveryPublicIdentity.kind.name.lowercase()
            )
          )
        }
        result.success(statesList)
      } catch (e: Exception) {
        result.error("STATIC_INBOX_STATES_FAILED", e.message, null)
      }
    }
  }

  private fun staticGetInboxIdForAddress(address: String, environment: String, result: Result) {
    scope.launch {
      try {
        val env = when (environment) {
          "dev" -> XMTPEnvironment.DEV
          "local" -> XMTPEnvironment.LOCAL
          else -> XMTPEnvironment.PRODUCTION
        }
        val api = ClientOptions.Api(env, true)
        val publicIdentity = PublicIdentity(IdentityKind.ETHEREUM, address)
        val inboxId = Client.getOrCreateInboxId(api, publicIdentity)
        result.success(inboxId)
      } catch (e: Exception) {
        result.error("STATIC_GET_INBOX_ID_FAILED", e.message, null)
      }
    }
  }

  private fun staticDeleteLocalDatabase(inboxId: String, environment: String, result: Result) {
    scope.launch {
      try {
        val env = when (environment) {
          "dev" -> XMTPEnvironment.DEV
          "local" -> XMTPEnvironment.LOCAL
          else -> XMTPEnvironment.PRODUCTION
        }
        val alias = "xmtp-${env}-${inboxId}"
        val dbDir = java.io.File(context.filesDir.absolutePath, "xmtp_db")
        val dbFile = java.io.File(dbDir, "${alias}.db3")
        if (dbFile.exists()) dbFile.delete()
        // Also clean up WAL/SHM if present
        val walFile = java.io.File(dbDir, "${alias}.db3-wal")
        val shmFile = java.io.File(dbDir, "${alias}.db3-shm")
        if (walFile.exists()) walFile.delete()
        if (shmFile.exists()) shmFile.delete()
        result.success(null)
      } catch (e: Exception) {
        result.error("STATIC_DELETE_DB_FAILED", e.message, null)
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    scope.cancel()
  }
}

data class GroupOptions(
  val name: String? = null,
  val description: String? = null,
  val imageUrl: String? = null,
  val pinnedFrameUrl: String? = null
)