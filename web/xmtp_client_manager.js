/**
 * XMTP Client Manager for Flutter Web - SDK v5.x
 *
 * This module provides a comprehensive JavaScript bridge between Flutter Web
 * and the XMTP Browser SDK v5, implementing all methods from the Flutter platform interface.
 */

import { Client } from '@xmtp/browser-sdk';

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
        console.warn('[XMTP] Client already initialized');
        return this.#client.inboxId;
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
   * Create a signer interface from a private key
   * This is a simplified implementation - production should use proper crypto
   */
  #createSignerFromPrivateKey(privateKeyBytes) {
    // Generate a mock Ethereum address from the private key
    const address = '0x' + Array.from(privateKeyBytes.slice(12, 32))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    return {
      type: 'EOA',
      getIdentifier: async () => ({
        identifier: address.toLowerCase(),
        identifierKind: 'Ethereum'
      }),
      signMessage: async (message) => {
        // Simplified signing - in production use proper ECDSA signing
        const encoder = new TextEncoder();
        const data = encoder.encode(message);
        const hashBuffer = await crypto.subtle.digest('SHA-256', data);
        return new Uint8Array(hashBuffer);
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
        identifierKind: 'Ethereum'
      };

      const dm = await this.#client.conversations.newDmWithIdentifier(identifier);

      // Extract content from message object
      const content = this.#extractMessageContent(message);

      // Send the message
      await dm.send(content);

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
      const dm = await this.#client.conversations.newDm(recipientInboxId);
      const content = this.#extractMessageContent(message);

      await dm.send(content);

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
      await group.send(content);

      return group.id;
    } catch (error) {
      console.error('[XMTP] Failed to send group message:', error);
      throw new Error(`Failed to send group message: ${error.message}`);
    }
  }

  /**
   * Extract message content from message object
   */
  #extractMessageContent(message) {
    if (typeof message === 'string') {
      return message;
    }
    if (message.content) {
      // If content is byte array, convert to string
      if (Array.isArray(message.content)) {
        const decoder = new TextDecoder();
        return decoder.decode(new Uint8Array(message.content));
      }
      return message.content;
    }
    return message;
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

            const messageData = {
              id: message.id,
              content: message.content,
              encodedContent: Array.from(new Uint8Array(message.encodedContent.content)),
              parameters: message.parameters || {},
              sent: Number(message.sentAtNs / BigInt(1000000)), // Convert ns to ms
              conversationTopic: message.conversationId,
              senderInboxId: message.senderInboxId,
              type: {
                authority_id: message.contentType.authorityId,
                type_id: message.contentType.typeId,
                version_major: message.contentType.versionMajor
              },
              members: members.map(m => ({
                inboxId: m.inboxId,
                addresses: m.addresses.join(',')
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
      await this.#client.conversations.sync();

      // Build options with consent state filter if provided
      const options = {};
      if (consentState) {
        options.consentStates = [this.#mapConsentState(consentState)];
      }

      const dms = await this.#client.conversations.listDms(options);

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
            addresses: m.addresses.join(',')
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
      await this.#client.conversations.sync();

      // Build options with consent state filter if provided
      const options = {};
      if (consentState) {
        options.consentStates = [this.#mapConsentState(consentState)];
      }

      const groups = await this.#client.conversations.listGroups(options);

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
            addresses: m.addresses.join(',')
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

      await conversation.updateConsentState('allowed');
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

      await conversation.updateConsentState('denied');
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
      const dm = await this.#client.conversations.newDm(inboxId);
      const members = await dm.members();
      const peerInboxId = await dm.peerInboxId();

      return {
        id: dm.id,
        topic: dm.id,
        createdAt: Number(dm.createdAtNs / BigInt(1000000)),
        peerInboxId: peerInboxId,
        members: members.map(m => ({
          inboxId: m.inboxId,
          addresses: m.addresses.join(',')
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
        identifierKind: 'Ethereum'
      };

      const inboxId = await this.#client.findInboxIdByIdentifier(identifier);
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
        identifierKind: 'Ethereum'
      };

      const dm = await this.#client.conversations.newDmWithIdentifier(identifier);
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
        identifierKind: 'Ethereum'
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
        identifierKind: 'Ethereum'
      };

      const dm = await this.#client.conversations.newDmWithIdentifier(identifier);

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
   */
  async #formatMessages(messages, conversation) {
    const members = await conversation.members();

    return messages.map(message => ({
      id: message.id,
      content: message.content,
      encodedContent: Array.from(new Uint8Array(message.encodedContent.content)),
      parameters: message.parameters || {},
      sent: Number(message.sentAtNs / BigInt(1000000)),
      conversationTopic: conversation.id,
      senderInboxId: message.senderInboxId,
      type: {
        authority_id: message.contentType.authorityId,
        type_id: message.contentType.typeId,
        version_major: message.contentType.versionMajor
      },
      members: members.map(m => ({
        inboxId: m.inboxId,
        addresses: m.addresses.join(',')
      }))
    }));
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
      const group = await this.#client.conversations.newGroup(inboxIds, {
        name: options.name || '',
        description: options.description || '',
        imageUrl: options.imageUrl || ''
      });

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
        address: m.addresses.join(',')
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
      // Use the client's method to get inbox states
      const inboxStates = await this.#client.inboxStatesForInboxIds(refreshFromNetwork, inboxIds);

      return inboxStates.map(state => ({
        inboxId: state.inboxId,
        identities: state.identities.map(id => ({
          identifier: id.identifier,
          kind: id.kind?.toLowerCase() || 'ethereum'
        })),
        installations: state.installations.map(inst => ({
          id: inst.id,
          createdAt: inst.clientTimestampNs ? Number(inst.clientTimestampNs / BigInt(1000000)) : null
        })),
        recoveryIdentity: {
          identifier: state.recoveryIdentity.identifier,
          kind: state.recoveryIdentity.kind?.toLowerCase() || 'ethereum'
        }
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
      const state = await this.#client.preferences.getConsentState('inbox_id', inboxId);
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
        entityType: 'inbox_id',
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

      const result = await this.#client.conversations.syncAll(states);
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
      await this.#client.conversations.sync();
      const conversations = await this.#client.conversations.list();

      const conversationList = [];
      for (const convo of conversations) {
        const members = await convo.members();
        const consent = await convo.consentState();
        const isGroup = convo.metadata?.conversationType === 'group';

        const item = {
          id: convo.id,
          topic: convo.id,
          createdAt: Number(convo.createdAtNs / BigInt(1000000)),
          consentState: this.#consentStateToString(consent),
          isGroup: isGroup,
          members: members.map(m => ({
            inboxId: m.inboxId,
            addresses: m.addresses.join(',')
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
      const dm = await this.#client.conversations.newDm(inboxId);
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
      const state = await this.#client.preferences.inboxState(refreshFromNetwork);

      return {
        inboxId: state.inboxId,
        identities: state.identifiers.map(id => ({
          identifier: id.identifier,
          kind: id.identifierKind?.toLowerCase() || 'ethereum'
        })),
        installations: state.installations.map(inst => ({
          id: inst.id,
          createdAt: inst.clientTimestampNs ? Number(inst.clientTimestampNs / BigInt(1000000)) : null
        })),
        recoveryIdentity: {
          identifier: state.recoveryIdentifier.identifier,
          kind: state.recoveryIdentifier.identifierKind?.toLowerCase() || 'ethereum'
        }
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
        identifierKind: 'Ethereum'
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
        identifierKind: 'Ethereum'
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
    const address = '0x' + Array.from(privateKeyBytes.slice(12, 32))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    return {
      type: 'EOA',
      getIdentifier: async () => ({
        identifier: address.toLowerCase(),
        identifierKind: 'Ethereum'
      }),
      signMessage: async (message) => {
        const encoder = new TextEncoder();
        const data = encoder.encode(message);
        const hashBuffer = await crypto.subtle.digest('SHA-256', data);
        return new Uint8Array(hashBuffer);
      }
    };
  }

  // ============================================================================
  // CONSENT STATE HELPERS
  // ============================================================================

  /**
   * Map string consent state to SDK enum value
   */
  #mapConsentState(state) {
    const stateMap = {
      'allowed': 'allowed',
      'denied': 'denied',
      'unknown': 'unknown'
    };
    return stateMap[state?.toLowerCase()] || 'unknown';
  }

  /**
   * Convert SDK consent state to string
   */
  #consentStateToString(state) {
    if (typeof state === 'string') return state.toLowerCase();
    // Handle enum-like objects
    if (state?.toString) return state.toString().toLowerCase();
    return 'unknown';
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

console.log('[XMTP] Client Manager v5 loaded and ready');

export default xmtpClientManager;
