/**
 * XMTP Client Manager for Flutter Web - SDK v6.x
 *
 * This module provides a comprehensive JavaScript bridge between Flutter Web
 * and the XMTP Browser SDK v6, implementing all methods from the Flutter platform interface.
 */

import { Client, ConsentState, ConsentEntityType, ConversationType, IdentifierKind } from '@xmtp/browser-sdk';
import { toBytes } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

/**
 * Singleton manager for XMTP client operations
 */
class XMTPClientManager {
  static #instance;
  #client = null;
  #messageCallbacks = new Map();
  #activeStreams = new Set();

  constructor() {
    console.log('[XMTP] Client Manager initialized');
  }

  static getInstance() {
    if (!XMTPClientManager.#instance) {
      XMTPClientManager.#instance = new XMTPClientManager();
    }
    return XMTPClientManager.#instance;
  }

  // ============================================================================
  // PRIVATE KEY & CLIENT INITIALIZATION
  // ============================================================================

  /**
   * Generate a new random private key (32 bytes)
   */
  async generatePrivateKey() {
    try {
      const privateKey = crypto.getRandomValues(new Uint8Array(32));
      return Array.from(privateKey);
    } catch (error) {
      console.error('[XMTP] Failed to generate private key:', error);
      throw new Error(`Failed to generate private key: ${error.message}`);
    }
  }

  /**
   * Initialize XMTP client with a private key
   * Creates a signer from the private key and initializes the client
   */
  async initializeClient({ privateKey, dbKey, environment = 'production' }) {
    try {
      if (this.#client) {
        console.log('[XMTP] Closing existing client before re-init...');
        // Clean up active streams
        for (const stream of this.#activeStreams) {
          try { stream.end?.(); } catch (_) {}
        }
        this.#activeStreams.clear();
        this.#messageCallbacks.clear();
        // Properly close the client (terminates the Web Worker and releases OPFS handles)
        try { this.#client.close(); } catch (_) {}
        this.#client = null;
      }

      const keyBytes = new Uint8Array(privateKey);
      const dbKeyBytes = dbKey ? new Uint8Array(dbKey) : undefined;

      // Create a simple EOA signer from private key
      // In production, you'd use proper crypto libraries (ethers.js, viem, etc.)
      const signer = this.#createSignerFromPrivateKey(keyBytes);

      console.log('[XMTP] Creating client with signer...');

      // Initialize the XMTP client
      this.#client = await Client.create(signer, {
        env: environment,
        dbPath: undefined, // Uses browser IndexedDB
        dbEncryptionKey: dbKeyBytes,
      });

      console.log('[XMTP] Client initialized successfully');
      console.log('[XMTP] Inbox ID:', this.#client.inboxId);
      console.log('[XMTP] Account:', this.#client.accountIdentifier);

      return this.#client.inboxId;
    } catch (error) {
      console.error('[XMTP] Failed to initialize client:', error);
      throw new Error(`Failed to initialize client: ${error.message}`);
    }
  }

  /**
   * Create a signer interface from a private key using viem for proper ECDSA signing
   */
  #createSignerFromPrivateKey(privateKeyBytes) {
    const hexKey = '0x' + Array.from(privateKeyBytes)
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    const account = privateKeyToAccount(hexKey);

    return {
      type: 'EOA',
      getIdentifier: () => ({
        identifier: account.address.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      }),
      signMessage: async (message) => {
        const signature = await account.signMessage({ message });
        return toBytes(signature);
      }
    };
  }

  /**
   * Get client address
   */
  async getClientAddress() {
    this.#ensureClientInitialized();
    const identifier = this.#client.accountIdentifier;
    return identifier?.identifier || null;
  }

  /**
   * Get client inbox ID
   */
  async getClientInboxId() {
    this.#ensureClientInitialized();
    return this.#client.inboxId;
  }

  // ============================================================================
  // MESSAGING
  // ============================================================================

  /**
   * Send message to recipient by address
   */
  async sendMessage({ recipientAddress, message, authorityId, typeId, versionMajor }) {
    this.#ensureClientInitialized();

    try {
      // Create DM conversation with the recipient
      const identifier = {
        identifier: recipientAddress.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      };

      const dm = await this.#client.conversations.createDmWithIdentifier(identifier);

      // Extract content from message object
      const content = this.#extractMessageContent(message);

      // Send the message as text
      await dm.sendText(content);

      return dm.id;
    } catch (error) {
      console.error('[XMTP] Failed to send message:', error);
      throw new Error(`Failed to send message: ${error.message}`);
    }
  }

  /**
   * Send message by inbox ID
   */
  async sendMessageByInboxId({ recipientInboxId, message, authorityId, typeId, versionMajor }) {
    this.#ensureClientInitialized();

    try {
      const dm = await this.#client.conversations.createDm(recipientInboxId);
      const content = this.#extractMessageContent(message);

      await dm.sendText(content);

      return dm.id;
    } catch (error) {
      console.error('[XMTP] Failed to send message by inbox ID:', error);
      throw new Error(`Failed to send message by inbox ID: ${error.message}`);
    }
  }

  /**
   * Send group message by topic
   */
  async sendGroupMessage({ topic, message, authorityId, typeId, versionMajor }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);

      if (!group) {
        throw new Error('Group not found');
      }

      const content = this.#extractMessageContent(message);
      await group.sendText(content);

      return group.id;
    } catch (error) {
      console.error('[XMTP] Failed to send group message:', error);
      throw new Error(`Failed to send group message: ${error.message}`);
    }
  }

  /**
   * Extract message content from message object.
   * The Dart codec layer encodes text as {content: Uint8List, parameters: {...}}.
   * On web, Uint8List arrives as various typed array forms.
   */
  #extractMessageContent(message) {
    if (typeof message === 'string') {
      return message;
    }
    if (message && message.content !== undefined) {
      const content = message.content;
      // Byte array (Array, Uint8Array, or any array-like with numeric values)
      if (content instanceof Uint8Array) {
        return new TextDecoder().decode(content);
      }
      if (Array.isArray(content)) {
        return new TextDecoder().decode(new Uint8Array(content));
      }
      // ArrayBuffer
      if (content instanceof ArrayBuffer) {
        return new TextDecoder().decode(new Uint8Array(content));
      }
      // Already a string
      if (typeof content === 'string') {
        return content;
      }
      // Dart List<int> may arrive as a JS object with numeric keys and length
      if (content.length !== undefined && typeof content !== 'string') {
        try {
          return new TextDecoder().decode(new Uint8Array(Array.from(content)));
        } catch (_) {}
      }
      return String(content);
    }
    // Fallback: try to stringify
    return typeof message === 'object' ? JSON.stringify(message) : String(message);
  }

  // ============================================================================
  // MESSAGE STREAMING
  // ============================================================================

  /**
   * Subscribe to all messages across all conversations
   */
  async subscribeToAllMessages(callback) {
    this.#ensureClientInitialized();

    try {
      console.log('[XMTP] Starting message subscription...');

      const stream = await this.#client.conversations.streamAllMessages();
      this.#activeStreams.add(stream);

      // Process messages asynchronously
      (async () => {
        try {
          for await (const message of stream) {
            console.log('[XMTP] Received message:', message);

            const conversation = await this.#client.conversations.getConversationById(message.conversationId);
            const members = await conversation.members();

            // In v6, content is already decoded — encode text as UTF-8 for backward compat
            const contentStr = typeof message.content === 'string' ? message.content : JSON.stringify(message.content);
            const encodedBytes = new TextEncoder().encode(contentStr);

            const messageData = {
              id: message.id,
              content: message.content,
              encodedContent: Array.from(encodedBytes),
              parameters: {},
              sent: Number(message.sentAtNs / BigInt(1000000)), // Convert ns to ms
              conversationTopic: message.conversationId,
              senderInboxId: message.senderInboxId,
              type: {
                authority_id: message.contentType?.authorityId ?? 'xmtp.org',
                type_id: message.contentType?.typeId ?? 'text',
                version_major: message.contentType?.versionMajor ?? 1
              },
              members: members.map(m => ({
                inboxId: m.inboxId,
                addresses: (m.accountIdentifiers || []).map(id => id.identifier).join(',')
              }))
            };

            callback(messageData);
          }
        } catch (error) {
          console.error('[XMTP] Error in message stream:', error);
        }
      })();

      return true;
    } catch (error) {
      console.error('[XMTP] Failed to subscribe to messages:', error);
      throw new Error(`Failed to subscribe to messages: ${error.message}`);
    }
  }

  // ============================================================================
  // CONVERSATION MANAGEMENT
  // ============================================================================

  /**
   * List all DM conversations
   * @param {Object} params - Optional parameters
   * @param {string} params.consentState - Filter by consent state ('allowed', 'denied', 'unknown')
   */
  async listDms({ consentState } = {}) {
    this.#ensureClientInitialized();

    try {
      console.log('[XMTP] listDms: syncing conversations...');
      await this.#client.conversations.sync();
      console.log('[XMTP] listDms: sync complete');

      // Build options with consent state filter if provided
      const options = {};
      if (consentState) {
        options.consentStates = [this.#mapConsentState(consentState)];
      }

      const dms = await this.#client.conversations.listDms(options);
      console.log('[XMTP] listDms: found', dms.length, 'DM(s)');

      const dmList = [];
      for (const dm of dms) {
        const members = await dm.members();
        const peerInboxId = await dm.peerInboxId();
        const consent = await dm.consentState();

        dmList.push({
          id: dm.id,
          topic: dm.id,
          createdAt: Number(dm.createdAtNs / BigInt(1000000)),
          peerInboxId: peerInboxId,
          consentState: this.#consentStateToString(consent),
          members: members.map(m => ({
            inboxId: m.inboxId,
            addresses: (m.accountIdentifiers || []).map(id => id.identifier).join(',')
          }))
        });
      }

      return dmList;
    } catch (error) {
      console.error('[XMTP] Failed to list DMs:', error);
      throw new Error(`Failed to list DMs: ${error.message}`);
    }
  }

  /**
   * List all group conversations
   * @param {Object} params - Optional parameters
   * @param {string} params.consentState - Filter by consent state ('allowed', 'denied', 'unknown')
   */
  async listGroups({ consentState } = {}) {
    this.#ensureClientInitialized();

    try {
      console.log('[XMTP] listGroups: syncing conversations...');
      await this.#client.conversations.sync();
      console.log('[XMTP] listGroups: sync complete');

      // Build options with consent state filter if provided
      const options = {};
      if (consentState) {
        options.consentStates = [this.#mapConsentState(consentState)];
      }

      const groups = await this.#client.conversations.listGroups(options);
      console.log('[XMTP] listGroups: found', groups.length, 'group(s)');

      const groupList = [];
      for (const group of groups) {
        const members = await group.members();
        const consent = await group.consentState();

        groupList.push({
          id: group.id,
          topic: group.id,
          createdAt: Number(group.createdAtNs / BigInt(1000000)),
          name: group.name || '',
          imageUrlSquare: group.imageUrl || '',
          description: group.description || '',
          consentState: this.#consentStateToString(consent),
          members: members.map(m => ({
            inboxId: m.inboxId,
            addresses: (m.accountIdentifiers || []).map(id => id.identifier).join(',')
          }))
        });
      }

      return groupList;
    } catch (error) {
      console.error('[XMTP] Failed to list groups:', error);
      throw new Error(`Failed to list groups: ${error.message}`);
    }
  }

  /**
   * Accept conversation by topic
   */
  async acceptConversation({ topic }) {
    this.#ensureClientInitialized();

    try {
      const conversation = await this.#client.conversations.getConversationById(topic);
      if (!conversation) {
        throw new Error('Conversation not found');
      }

      await conversation.updateConsentState(ConsentState.Allowed);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to accept conversation:', error);
      throw new Error(`Failed to accept conversation: ${error.message}`);
    }
  }

  /**
   * Deny conversation by topic
   */
  async denyConversation({ topic }) {
    this.#ensureClientInitialized();

    try {
      const conversation = await this.#client.conversations.getConversationById(topic);
      if (!conversation) {
        throw new Error('Conversation not found');
      }

      await conversation.updateConsentState(ConsentState.Denied);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to deny conversation:', error);
      throw new Error(`Failed to deny conversation: ${error.message}`);
    }
  }

  /**
   * Find or create DM with inbox ID
   */
  async findOrCreateDMWithInboxId({ inboxId }) {
    this.#ensureClientInitialized();

    try {
      const dm = await this.#client.conversations.createDm(inboxId);
      const members = await dm.members();
      const peerInboxId = await dm.peerInboxId();

      return {
        id: dm.id,
        topic: dm.id,
        createdAt: Number(dm.createdAtNs / BigInt(1000000)),
        peerInboxId: peerInboxId,
        members: members.map(m => ({
          inboxId: m.inboxId,
          addresses: (m.accountIdentifiers || []).map(id => id.identifier).join(',')
        }))
      };
    } catch (error) {
      console.error('[XMTP] Failed to find or create DM:', error);
      throw new Error(`Failed to find or create DM: ${error.message}`);
    }
  }

  /**
   * Get inbox ID from address
   */
  async inboxIdFromAddress({ address }) {
    this.#ensureClientInitialized();

    try {
      const identifier = {
        identifier: address.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      };

      const inboxId = await this.#client.fetchInboxIdByIdentifier(identifier);
      return inboxId;
    } catch (error) {
      console.error('[XMTP] Failed to get inbox ID from address:', error);
      throw new Error(`Failed to get inbox ID from address: ${error.message}`);
    }
  }

  /**
   * Get conversation topic from address
   */
  async conversationTopicFromAddress({ peerAddress }) {
    this.#ensureClientInitialized();

    try {
      const identifier = {
        identifier: peerAddress.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      };

      const dm = await this.#client.conversations.createDmWithIdentifier(identifier);
      return dm.id;
    } catch (error) {
      console.error('[XMTP] Failed to get conversation topic:', error);
      throw new Error(`Failed to get conversation topic: ${error.message}`);
    }
  }

  /**
   * Check if can message address
   */
  async canMessage({ address }) {
    this.#ensureClientInitialized();

    try {
      const identifier = {
        identifier: address.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      };

      const result = await this.#client.canMessage([identifier]);
      return result.get(identifier.identifier) || false;
    } catch (error) {
      console.error('[XMTP] Failed to check if can message:', error);
      throw new Error(`Failed to check if can message: ${error.message}`);
    }
  }

  // ============================================================================
  // MESSAGE RETRIEVAL
  // ============================================================================

  /**
   * Get messages after date by peer address
   */
  async getMessagesAfterDate({ peerAddress, fromDate }) {
    this.#ensureClientInitialized();

    try {
      const identifier = {
        identifier: peerAddress.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      };

      const dm = await this.#client.conversations.createDmWithIdentifier(identifier);

      const afterNs = BigInt(fromDate) * BigInt(1000000); // Convert ms to ns
      const messages = await dm.messages({ afterNs });

      return this.#formatMessages(messages, dm);
    } catch (error) {
      console.error('[XMTP] Failed to get messages after date:', error);
      throw new Error(`Failed to get messages after date: ${error.message}`);
    }
  }

  /**
   * Get messages after date by topic
   */
  async getMessagesAfterDateByTopic({ topic, fromDate }) {
    this.#ensureClientInitialized();

    try {
      const conversation = await this.#client.conversations.getConversationById(topic);
      if (!conversation) {
        throw new Error('Conversation not found');
      }

      const afterNs = BigInt(fromDate) * BigInt(1000000);
      const messages = await conversation.messages({ afterNs });

      return this.#formatMessages(messages, conversation);
    } catch (error) {
      console.error('[XMTP] Failed to get messages after date by topic:', error);
      throw new Error(`Failed to get messages after date by topic: ${error.message}`);
    }
  }

  /**
   * Format messages for Flutter
   * In v6, message.content is already decoded — we encode as UTF-8 for backward compat
   */
  async #formatMessages(messages, conversation) {
    const members = await conversation.members();

    return messages.map(message => {
      const contentStr = typeof message.content === 'string' ? message.content : JSON.stringify(message.content);
      const encodedBytes = new TextEncoder().encode(contentStr);

      return {
        id: message.id,
        content: message.content,
        encodedContent: Array.from(encodedBytes),
        parameters: {},
        sent: Number(message.sentAtNs / BigInt(1000000)),
        conversationTopic: conversation.id,
        senderInboxId: message.senderInboxId,
        type: {
          authority_id: message.contentType?.authorityId ?? 'xmtp.org',
          type_id: message.contentType?.typeId ?? 'text',
          version_major: message.contentType?.versionMajor ?? 1
        },
        members: members.map(m => ({
          inboxId: m.inboxId,
          addresses: (m.accountIdentifiers || []).map(id => id.identifier).join(',')
        }))
      };
    });
  }

  // ============================================================================
  // GROUP OPERATIONS
  // ============================================================================

  /**
   * Create new group
   */
  async newGroup({ inboxIds, options }) {
    this.#ensureClientInitialized();

    try {
      console.log('[XMTP] createGroup raw args:', typeof inboxIds, typeof options);
      console.log('[XMTP] createGroup inboxIds:', JSON.stringify(inboxIds));
      console.log('[XMTP] createGroup options:', JSON.stringify(options));
      console.log('[XMTP] createGroup options keys:', options ? Object.keys(options) : 'null/undefined');
      // If options is a Dart jsify'd object, try enumerating properties
      if (options) {
        for (const k in options) {
          console.log('[XMTP]   option key:', k, '=', options[k]);
        }
      }
      const groupOptions = {};
      if (options?.name) groupOptions.name = options.name;
      if (options?.description) groupOptions.description = options.description;
      if (options?.imageUrl) groupOptions.imageUrl = options.imageUrl;
      console.log('[XMTP] createGroup resolved options:', JSON.stringify(groupOptions));
      const group = await this.#client.conversations.createGroup(inboxIds, groupOptions);

      return {
        id: group.id,
        topic: group.id,
        createdAt: Number(group.createdAtNs / BigInt(1000000)).toString(),
        name: group.name || '',
        imageUrlSquare: group.imageUrl || '',
        description: group.description || ''
      };
    } catch (error) {
      console.error('[XMTP] Failed to create new group:', error);
      throw new Error(`Failed to create new group: ${error.message}`);
    }
  }

  /**
   * List group members
   */
  async listGroupMembers({ topic }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      const members = await group.members();
      return members.map(m => ({
        inboxId: m.inboxId,
        address: (m.accountIdentifiers || []).map(id => id.identifier).join(',')
      }));
    } catch (error) {
      console.error('[XMTP] Failed to list group members:', error);
      throw new Error(`Failed to list group members: ${error.message}`);
    }
  }

  /**
   * List group admins
   */
  async listGroupAdmins({ topic }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      const admins = await group.listAdmins();
      return admins.map(inboxId => ({ inboxId }));
    } catch (error) {
      console.error('[XMTP] Failed to list group admins:', error);
      throw new Error(`Failed to list group admins: ${error.message}`);
    }
  }

  /**
   * List group super admins
   */
  async listGroupSuperAdmins({ topic }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      const superAdmins = await group.listSuperAdmins();
      return superAdmins.map(inboxId => ({ inboxId }));
    } catch (error) {
      console.error('[XMTP] Failed to list group super admins:', error);
      throw new Error(`Failed to list group super admins: ${error.message}`);
    }
  }

  /**
   * Add group members
   */
  async addGroupMembers({ topic, inboxIds }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      await group.addMembers(inboxIds);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to add group members:', error);
      throw new Error(`Failed to add group members: ${error.message}`);
    }
  }

  /**
   * Remove group members
   */
  async removeGroupMembers({ topic, inboxIds }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      await group.removeMembers(inboxIds);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to remove group members:', error);
      throw new Error(`Failed to remove group members: ${error.message}`);
    }
  }

  /**
   * Add group admin
   */
  async addGroupAdmin({ topic, inboxId }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      await group.addAdmin(inboxId);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to add group admin:', error);
      throw new Error(`Failed to add group admin: ${error.message}`);
    }
  }

  /**
   * Remove group admin
   */
  async removeGroupAdmin({ topic, inboxId }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      await group.removeAdmin(inboxId);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to remove group admin:', error);
      throw new Error(`Failed to remove group admin: ${error.message}`);
    }
  }

  /**
   * Add group super admin
   */
  async addGroupSuperAdmin({ topic, inboxId }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      await group.addSuperAdmin(inboxId);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to add group super admin:', error);
      throw new Error(`Failed to add group super admin: ${error.message}`);
    }
  }

  /**
   * Remove group super admin
   */
  async removeGroupSuperAdmin({ topic, inboxId }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      await group.removeSuperAdmin(inboxId);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to remove group super admin:', error);
      throw new Error(`Failed to remove group super admin: ${error.message}`);
    }
  }

  /**
   * Update group metadata
   */
  async updateGroup({ topic, updates }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      if (updates.name) {
        await group.updateName(updates.name);
      }
      if (updates.description) {
        await group.updateDescription(updates.description);
      }
      if (updates.imageUrl) {
        await group.updateImageUrl(updates.imageUrl);
      }

      return true;
    } catch (error) {
      console.error('[XMTP] Failed to update group:', error);
      throw new Error(`Failed to update group: ${error.message}`);
    }
  }

  /**
   * Get group member role
   */
  async getGroupMemberRole({ topic, inboxId }) {
    this.#ensureClientInitialized();

    try {
      const group = await this.#client.conversations.getConversationById(topic);
      if (!group) {
        throw new Error('Group not found');
      }

      const isAdmin = await group.isAdmin(inboxId);
      const isSuperAdmin = await group.isSuperAdmin(inboxId);

      return {
        isAdmin,
        isSuperAdmin
      };
    } catch (error) {
      console.error('[XMTP] Failed to get group member role:', error);
      throw new Error(`Failed to get group member role: ${error.message}`);
    }
  }

  // ============================================================================
  // ATTACHMENTS
  // ============================================================================

  /**
   * Get inbox states for inbox IDs
   * Returns identities (ETH addresses) associated with each inbox
   */
  async inboxStatesForInboxIds({ inboxIds, refreshFromNetwork = true }) {
    this.#ensureClientInitialized();

    try {
      // v6: split into getInboxStates (local) and fetchInboxStates (network)
      const inboxStates = refreshFromNetwork
        ? await this.#client.preferences.fetchInboxStates(inboxIds)
        : await this.#client.preferences.getInboxStates(inboxIds);

      return inboxStates.map(state => ({
        inboxId: state.inboxId,
        identities: (state.accountIdentifiers || []).map(id => ({
          identifier: id.identifier,
          kind: this.#identifierKindToString(id.identifierKind)
        })),
        installations: (state.installations || []).map(inst => ({
          id: inst.id,
          createdAt: inst.clientTimestampNs ? Number(inst.clientTimestampNs / BigInt(1000000)) : null
        })),
        recoveryIdentity: state.recoveryIdentifier ? {
          identifier: state.recoveryIdentifier.identifier,
          kind: this.#identifierKindToString(state.recoveryIdentifier.identifierKind)
        } : null
      }));
    } catch (error) {
      console.error('[XMTP] Failed to get inbox states:', error);
      throw new Error(`Failed to get inbox states: ${error.message}`);
    }
  }

  /**
   * Load remote attachment
   */
  async loadRemoteAttachment(params) {
    try {
      const response = await fetch(params.url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.arrayBuffer();

      // TODO: Implement decryption using secret, salt, nonce
      // For now, return raw data

      return {
        filename: params.filename || 'attachment',
        mimeType: response.headers.get('content-type') || 'application/octet-stream',
        data: Array.from(new Uint8Array(data))
      };
    } catch (error) {
      console.error('[XMTP] Failed to load remote attachment:', error);
      throw new Error(`Failed to load remote attachment: ${error.message}`);
    }
  }

  // ============================================================================
  // CONSENT MANAGEMENT
  // ============================================================================

  /**
   * Get conversation consent state by topic
   */
  async getConversationConsentState({ topic }) {
    this.#ensureClientInitialized();

    try {
      const conversation = await this.#client.conversations.getConversationById(topic);
      if (!conversation) {
        throw new Error('Conversation not found');
      }

      const state = await conversation.consentState();
      return this.#consentStateToString(state);
    } catch (error) {
      console.error('[XMTP] Failed to get conversation consent state:', error);
      throw new Error(`Failed to get conversation consent state: ${error.message}`);
    }
  }

  /**
   * Set conversation consent state by topic
   */
  async setConversationConsentState({ topic, state }) {
    this.#ensureClientInitialized();

    try {
      const conversation = await this.#client.conversations.getConversationById(topic);
      if (!conversation) {
        throw new Error('Conversation not found');
      }

      await conversation.updateConsentState(this.#mapConsentState(state));
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to set conversation consent state:', error);
      throw new Error(`Failed to set conversation consent state: ${error.message}`);
    }
  }

  /**
   * Get inbox consent state by inbox ID
   */
  async getInboxConsentState({ inboxId }) {
    this.#ensureClientInitialized();

    try {
      const state = await this.#client.preferences.getConsentState(ConsentEntityType.InboxId, inboxId);
      return this.#consentStateToString(state);
    } catch (error) {
      console.error('[XMTP] Failed to get inbox consent state:', error);
      throw new Error(`Failed to get inbox consent state: ${error.message}`);
    }
  }

  /**
   * Set inbox consent state by inbox ID
   */
  async setInboxConsentState({ inboxId, state }) {
    this.#ensureClientInitialized();

    try {
      await this.#client.preferences.setConsentStates([{
        entityType: ConsentEntityType.InboxId,
        entity: inboxId,
        state: this.#mapConsentState(state)
      }]);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to set inbox consent state:', error);
      throw new Error(`Failed to set inbox consent state: ${error.message}`);
    }
  }

  /**
   * Sync consent preferences from network
   */
  async syncConsentPreferences() {
    this.#ensureClientInitialized();

    try {
      await this.#client.preferences.sync();
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to sync consent preferences:', error);
      throw new Error(`Failed to sync consent preferences: ${error.message}`);
    }
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /**
   * Send a sync request to trigger history transfer
   */
  async sendSyncRequest() {
    this.#ensureClientInitialized();

    try {
      await this.#client.sendSyncRequest();
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to send sync request:', error);
      throw new Error(`Failed to send sync request: ${error.message}`);
    }
  }

  /**
   * Sync all conversations from network
   * @param {Object} params - Parameters
   * @param {string[]} params.consentStates - Filter by consent states
   */
  async syncAll({ consentStates } = {}) {
    this.#ensureClientInitialized();

    try {
      const states = consentStates
        ? consentStates.map(s => this.#mapConsentState(s))
        : undefined;

      console.log('[XMTP] syncAll: consent states =', states, ', syncing...');
      const result = await this.#client.conversations.syncAll(states);
      console.log('[XMTP] syncAll: complete, result =', result);

      // Also call conversations.sync() to discover new conversations
      console.log('[XMTP] syncAll: also running conversations.sync()...');
      await this.#client.conversations.sync();
      console.log('[XMTP] syncAll: conversations.sync() complete');

      // List all conversations to see what we have after sync
      const allConvos = await this.#client.conversations.list();
      console.log('[XMTP] syncAll: total conversations after sync =', allConvos.length);
      for (const c of allConvos) {
        console.log('[XMTP]   convo:', c.id, 'type:', c.metadata?.conversationType);
      }

      return { numGroupsSynced: result || 0 };
    } catch (error) {
      console.error('[XMTP] Failed to sync all:', error);
      throw new Error(`Failed to sync all: ${error.message}`);
    }
  }

  /**
   * Sync a single conversation by topic
   */
  async syncConversation({ topic }) {
    this.#ensureClientInitialized();

    try {
      const conversation = await this.#client.conversations.getConversationById(topic);
      if (!conversation) {
        throw new Error('Conversation not found');
      }

      await conversation.sync();
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to sync conversation:', error);
      throw new Error(`Failed to sync conversation: ${error.message}`);
    }
  }

  // ============================================================================
  // ADDITIONAL CONVERSATION METHODS
  // ============================================================================

  /**
   * List all conversations (DMs and Groups)
   */
  async listConversations() {
    this.#ensureClientInitialized();

    try {
      console.log('[XMTP] listConversations: syncing...');
      await this.#client.conversations.sync();
      const conversations = await this.#client.conversations.list();
      console.log('[XMTP] listConversations: found', conversations.length, 'conversation(s)');

      const conversationList = [];
      for (const convo of conversations) {
        const members = await convo.members();
        const consent = await convo.consentState();
        const convType = convo.metadata?.conversationType;
        const isGroup = convType === ConversationType.Group || convType === 'group';

        const item = {
          id: convo.id,
          topic: convo.id,
          createdAt: Number(convo.createdAtNs / BigInt(1000000)),
          consentState: this.#consentStateToString(consent),
          isGroup: isGroup,
          members: members.map(m => ({
            inboxId: m.inboxId,
            addresses: (m.accountIdentifiers || []).map(id => id.identifier).join(',')
          }))
        };

        if (isGroup) {
          item.name = convo.name || '';
          item.imageUrlSquare = convo.imageUrl || '';
          item.description = convo.description || '';
        } else {
          item.peerInboxId = await convo.peerInboxId();
        }

        conversationList.push(item);
      }

      return conversationList;
    } catch (error) {
      console.error('[XMTP] Failed to list conversations:', error);
      throw new Error(`Failed to list conversations: ${error.message}`);
    }
  }

  /**
   * Check if can message by inbox ID
   */
  async canMessageByInboxId({ inboxId }) {
    this.#ensureClientInitialized();

    try {
      // For inbox IDs, we try to create a DM - if it succeeds, they can be messaged
      const dm = await this.#client.conversations.createDm(inboxId);
      return dm !== null;
    } catch (error) {
      console.error('[XMTP] Failed to check if can message by inbox ID:', error);
      return false;
    }
  }

  // ============================================================================
  // INBOX MANAGEMENT
  // ============================================================================

  /**
   * Get current installation ID
   */
  async getInstallationId() {
    this.#ensureClientInitialized();
    return this.#client.installationId;
  }

  /**
   * Get inbox state for current client
   * @param {Object} params - Parameters
   * @param {boolean} params.refreshFromNetwork - Whether to refresh from network
   */
  async inboxState({ refreshFromNetwork = false } = {}) {
    this.#ensureClientInitialized();

    try {
      // v6: split into inboxState() (local) and fetchInboxState() (network)
      const state = refreshFromNetwork
        ? await this.#client.preferences.fetchInboxState()
        : await this.#client.preferences.inboxState();

      return {
        inboxId: state.inboxId,
        identities: (state.accountIdentifiers || []).map(id => ({
          identifier: id.identifier,
          kind: this.#identifierKindToString(id.identifierKind)
        })),
        installations: (state.installations || []).map(inst => ({
          id: inst.id,
          createdAt: inst.clientTimestampNs ? Number(inst.clientTimestampNs / BigInt(1000000)) : null
        })),
        recoveryIdentity: state.recoveryIdentifier ? {
          identifier: state.recoveryIdentifier.identifier,
          kind: this.#identifierKindToString(state.recoveryIdentifier.identifierKind)
        } : null
      };
    } catch (error) {
      console.error('[XMTP] Failed to get inbox state:', error);
      throw new Error(`Failed to get inbox state: ${error.message}`);
    }
  }

  /**
   * Revoke specific installations
   * @param {Object} params - Parameters
   * @param {number[]} params.signerPrivateKey - Private key bytes for signing
   * @param {string[]} params.installationIds - Installation IDs to revoke
   */
  async revokeInstallations({ signerPrivateKey, installationIds }) {
    this.#ensureClientInitialized();

    try {
      await this.#client.revokeInstallations(installationIds);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to revoke installations:', error);
      throw new Error(`Failed to revoke installations: ${error.message}`);
    }
  }

  /**
   * Revoke all other installations
   * @param {Object} params - Parameters
   * @param {number[]} params.signerPrivateKey - Private key bytes for signing
   */
  async revokeAllOtherInstallations({ signerPrivateKey }) {
    this.#ensureClientInitialized();

    try {
      await this.#client.revokeAllOtherInstallations();
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to revoke all other installations:', error);
      throw new Error(`Failed to revoke all other installations: ${error.message}`);
    }
  }

  /**
   * Add a new account to the inbox
   * @param {Object} params - Parameters
   * @param {number[]} params.newAccountPrivateKey - Private key bytes for new account
   * @param {boolean} params.allowReassignInboxId - Allow reassigning inbox ID (dangerous!)
   */
  async addAccount({ newAccountPrivateKey, allowReassignInboxId = false }) {
    this.#ensureClientInitialized();

    try {
      const keyBytes = new Uint8Array(newAccountPrivateKey);
      const newSigner = this.#createSignerFromPrivateKey(keyBytes);

      await this.#client.unsafe_addAccount(newSigner, allowReassignInboxId);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to add account:', error);
      throw new Error(`Failed to add account: ${error.message}`);
    }
  }

  /**
   * Remove an account from the inbox
   * @param {Object} params - Parameters
   * @param {number[]} params.recoveryPrivateKey - Recovery private key bytes
   * @param {string} params.identifierToRemove - Address/identifier to remove
   */
  async removeAccount({ recoveryPrivateKey, identifierToRemove }) {
    this.#ensureClientInitialized();

    try {
      const identifier = {
        identifier: identifierToRemove.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      };

      await this.#client.removeAccount(identifier);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to remove account:', error);
      throw new Error(`Failed to remove account: ${error.message}`);
    }
  }

  /**
   * Change recovery identifier
   * @param {Object} params - Parameters
   * @param {number[]} params.signerPrivateKey - Current recovery key bytes
   * @param {string} params.newRecoveryIdentifier - New recovery address
   */
  async changeRecoveryIdentifier({ signerPrivateKey, newRecoveryIdentifier }) {
    this.#ensureClientInitialized();

    try {
      const identifier = {
        identifier: newRecoveryIdentifier.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      };

      await this.#client.changeRecoveryIdentifier(identifier);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to change recovery identifier:', error);
      throw new Error(`Failed to change recovery identifier: ${error.message}`);
    }
  }

  /**
   * Static method to revoke installations without an active client
   */
  static async staticRevokeInstallations({ signerPrivateKey, inboxId, installationIds, env = 'production' }) {
    try {
      const keyBytes = new Uint8Array(signerPrivateKey);
      const signer = XMTPClientManager.#createStaticSigner(keyBytes);

      await Client.revokeInstallations(signer, inboxId, installationIds, env);
      return true;
    } catch (error) {
      console.error('[XMTP] Failed to static revoke installations:', error);
      throw new Error(`Failed to static revoke installations: ${error.message}`);
    }
  }

  /**
   * Create a static signer (for use without instance)
   */
  static #createStaticSigner(privateKeyBytes) {
    const hexKey = '0x' + Array.from(privateKeyBytes)
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    const account = privateKeyToAccount(hexKey);

    return {
      type: 'EOA',
      getIdentifier: () => ({
        identifier: account.address.toLowerCase(),
        identifierKind: IdentifierKind.Ethereum
      }),
      signMessage: async (message) => {
        const signature = await account.signMessage({ message });
        return toBytes(signature);
      }
    };
  }

  // ============================================================================
  // CONSENT STATE HELPERS
  // ============================================================================

  /**
   * Convert IdentifierKind enum (number) to string
   */
  #identifierKindToString(kind) {
    // IdentifierKind.Ethereum = 0, IdentifierKind.Passkey = 1
    switch (kind) {
      case 0: return 'ethereum';
      case 1: return 'passkey';
      default: return 'ethereum';
    }
  }

  /**
   * Map string consent state to SDK v6 ConsentState enum
   */
  #mapConsentState(state) {
    const stateMap = {
      'allowed': ConsentState.Allowed,
      'denied': ConsentState.Denied,
      'unknown': ConsentState.Unknown
    };
    return stateMap[state?.toLowerCase()] ?? ConsentState.Unknown;
  }

  /**
   * Convert SDK v6 ConsentState enum to string
   */
  #consentStateToString(state) {
    switch (state) {
      case ConsentState.Allowed: return 'allowed';
      case ConsentState.Denied: return 'denied';
      case ConsentState.Unknown: return 'unknown';
      default:
        // Fallback for any unexpected values
        if (typeof state === 'string') return state.toLowerCase();
        return 'unknown';
    }
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  #ensureClientInitialized() {
    if (!this.#client) {
      throw new Error('XMTP client not initialized. Call initializeClient first.');
    }
  }
}

// Initialize and expose globally
const xmtpClientManager = XMTPClientManager.getInstance();
window.xmtpClientManager = xmtpClientManager;

console.log('[XMTP] Client Manager v6 loaded and ready');

export default xmtpClientManager;
