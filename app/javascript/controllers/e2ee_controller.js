import { Controller } from "@hotwired/stimulus"

const LEGACY_DEVICE_BUNDLE_KEY = "homechat_e2ee_device_bundle_v1"
const DEVICE_BUNDLE_KEY = "homechat_e2ee_device_bundle_v2"
const TOFU_PINS_KEY = "homechat_e2ee_tofu_pins_v2"
const LEGACY_CHANNEL_KEY_PREFIX = "homechat_e2ee_channel_key_"
const CHANNEL_KEY_PREFIX = "homechat_e2ee_channel_key_v2_"
const KEY_DB_NAME = "homechat_e2ee_key_store_v2"
const KEY_DB_VERSION = 1
const KEY_STORE_NAME = "keys"
const E2EE_VERSION = "1"
const KEY_SHARE_PREFIX = "homechat-key-share-v2"
const KEY_SHARE_WRAP_SALT = "homechat-e2ee-channel-key"
const PLACEHOLDER = "[Encrypted message]"

export default class extends Controller {
  static targets = ["contentEncoding", "encryptedContent", "contentHmac", "deviceId", "version", "senderKeyFingerprint"]
  static values = {
    channelId: Number,
    channelType: String,
    currentUserId: Number
  }

  async connect() {
    if (!this._required()) return

    this._submitting = false
    this._blockedFingerprints = new Set()
    this._memberKeyMap = new Map()
    this._keyEpoch = 0

    try {
      this._removeLegacyKeyMaterial()
      await this._loadOrCreateDeviceBundle()
      await this._publishKeyBundle()
      await this._refreshMemberKeys()
      await this._ensureChannelKey()
      await this._decryptVisibleMessages()
      this._observeMessages()
    } catch (error) {
      console.error("E2EE initialization failed", error)
      this._notify("E2EE setup failed. Sending is blocked until setup succeeds.")
      this._failedInit = true
    }
  }

  disconnect() {
    if (this._observer) {
      this._observer.disconnect()
      this._observer = null
    }
  }

  async beforeSubmit(event) {
    if (event.defaultPrevented) return
    if (!this._required()) return
    if (this._submitting) return

    if (this._failedInit) {
      event.preventDefault()
      this._notify("E2EE setup has not completed. Message not sent.")
      return
    }

    const form = event.target
    if (!(form instanceof HTMLFormElement)) return

    const textarea = form.querySelector('textarea[name="message[content]"]')
    if (!textarea) return

    const plaintext = textarea.value.toString()
    if (!plaintext.trim()) return

    const fileInput = form.querySelector('input[type="file"]')
    if (fileInput && fileInput.files && fileInput.files.length > 0) {
      event.preventDefault()
      this._notify("Attachments are disabled in encrypted private/direct channels.")
      return
    }

    event.preventDefault()

    if (this._blockedFingerprints.size > 0) {
      this._notify("A participant key changed. Sending is blocked until trust is reset.")
      return
    }

    await this._ensureChannelKey()
    await this._refreshMemberKeys()
    await this._shareChannelKeyWithMembers()

    const encryptedPayload = await this._encryptText(plaintext)
    const contentHmac = await this._computeHmac(encryptedPayload)

    this.contentEncodingTarget.value = "e2ee"
    this.encryptedContentTarget.value = encryptedPayload
    this.contentHmacTarget.value = contentHmac
    this.deviceIdTarget.value = this._deviceBundle.deviceId
    this.versionTarget.value = E2EE_VERSION
    this.senderKeyFingerprintTarget.value = this._deviceBundle.keyFingerprint

    textarea.value = PLACEHOLDER

    this._submitting = true
    form.requestSubmit()
    setTimeout(() => {
      this._submitting = false
    }, 0)
  }

  async _loadOrCreateDeviceBundle() {
    localStorage.removeItem(DEVICE_BUNDLE_KEY)

    const existing = await this._idbGet(DEVICE_BUNDLE_KEY)
    if (existing) {
      try {
        this._deviceBundle = await this._importDeviceBundle(existing)
        return
      } catch (error) {
        console.warn("Stored E2EE device bundle is invalid; generating a new device key.", error)
        await this._idbDelete(DEVICE_BUNDLE_KEY)
      }
    }

    const encryptionKeys = await this._generateKeyPair("X25519", ["deriveBits"])
    const signingKeys = await this._generateKeyPair("Ed25519", ["sign", "verify"])

    const encryptionPublicKey = this._bytesToBase64(new Uint8Array(await crypto.subtle.exportKey("raw", encryptionKeys.publicKey)))
    const signingPublicKey = this._bytesToBase64(new Uint8Array(await crypto.subtle.exportKey("raw", signingKeys.publicKey)))

    const fingerprint = await this._fingerprint(encryptionPublicKey, signingPublicKey)

    const stored = {
      deviceId: (crypto.randomUUID ? crypto.randomUUID() : `device-${Date.now()}`),
      encryptionPublicKey,
      signingPublicKey,
      keyFingerprint: fingerprint,
      encryptionPrivateCryptoKey: encryptionKeys.privateKey,
      signingPrivateCryptoKey: signingKeys.privateKey
    }

    await this._idbSet(DEVICE_BUNDLE_KEY, stored)
    this._deviceBundle = await this._importDeviceBundle(stored)
  }

  async _importDeviceBundle(serialized) {
    if (!serialized?.deviceId || !serialized?.encryptionPublicKey || !serialized?.signingPublicKey) {
      throw new Error("Stored E2EE device bundle metadata is incomplete")
    }

    const encryptionPrivateCryptoKey = serialized.encryptionPrivateCryptoKey
    const signingPrivateCryptoKey = serialized.signingPrivateCryptoKey
    if (!(encryptionPrivateCryptoKey instanceof CryptoKey) || !(signingPrivateCryptoKey instanceof CryptoKey)) {
      throw new Error("Stored E2EE private keys are not non-extractable CryptoKeys")
    }

    const encryptionPublicCryptoKey = await this._importX25519Public(serialized.encryptionPublicKey)
    const signingPublicCryptoKey = await this._importEd25519Public(serialized.signingPublicKey, ["verify"])
    const fingerprint = await this._fingerprint(serialized.encryptionPublicKey, serialized.signingPublicKey)

    return {
      deviceId: serialized.deviceId,
      encryptionPublicKey: serialized.encryptionPublicKey,
      signingPublicKey: serialized.signingPublicKey,
      keyFingerprint: fingerprint,
      encryptionPrivateCryptoKey,
      encryptionPublicCryptoKey,
      signingPrivateCryptoKey,
      signingPublicCryptoKey
    }
  }

  async _publishKeyBundle() {
    await this._request("/api/v1/me/e2ee_key", {
      method: "PUT",
      body: JSON.stringify({
        device_id: this._deviceBundle.deviceId,
        encryption_public_key: this._deviceBundle.encryptionPublicKey,
        signing_public_key: this._deviceBundle.signingPublicKey,
        key_fingerprint: this._deviceBundle.keyFingerprint,
        key_version: E2EE_VERSION
      })
    })
  }

  async _refreshMemberKeys() {
    const result = await this._request(`/api/v1/channels/${this.channelIdValue}/e2ee_keys`, {
      method: "GET"
    })

    this._keyEpoch = Number.isInteger(result.key_epoch) ? result.key_epoch : 0
    this._memberKeyMap.clear()

    const pins = this._loadPins()
    const members = Array.isArray(result.members) ? result.members : []

    for (const member of members) {
      if (!member.device_id || !member.encryption_public_key || !member.signing_public_key) continue

      const fingerprint = member.key_fingerprint || await this._fingerprint(member.encryption_public_key, member.signing_public_key)
      const pinKey = `${member.user_id}:${member.device_id}`
      const existingFingerprint = pins[pinKey]
      if (!existingFingerprint) {
        pins[pinKey] = fingerprint
      } else if (existingFingerprint !== fingerprint) {
        this._blockedFingerprints.add(fingerprint)
      }

      this._memberKeyMap.set(pinKey, { ...member, key_fingerprint: fingerprint })
    }

    localStorage.setItem(TOFU_PINS_KEY, JSON.stringify(pins))
  }

  async _ensureChannelKey() {
    if (this._channelKey) return

    const stored = await this._idbGet(this._channelStorageKey())
    if (stored) {
      const raw = this._bytesFromStoredValue(stored)
      this._channelKey = await crypto.subtle.importKey("raw", raw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"])
      this._channelKeyRaw = raw
      return
    }

    const fetched = await this._fetchMyKeyShare()
    if (fetched) {
      const decryptedRaw = await this._decryptChannelShare(fetched)
      if (decryptedRaw) {
        this._channelKeyRaw = decryptedRaw
        this._channelKey = await crypto.subtle.importKey("raw", decryptedRaw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"])
        await this._idbSet(this._channelStorageKey(), decryptedRaw)
        return
      }
    }

    this._channelKeyRaw = crypto.getRandomValues(new Uint8Array(32))
    this._channelKey = await crypto.subtle.importKey("raw", this._channelKeyRaw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"])
    await this._idbSet(this._channelStorageKey(), this._channelKeyRaw)
    await this._shareChannelKeyWithMembers()
  }

  async _shareChannelKeyWithMembers() {
    const shares = []
    const keyEpoch = Number.isInteger(this._keyEpoch) ? this._keyEpoch : 0

    for (const member of this._memberKeyMap.values()) {
      if (member.user_id === this.currentUserIdValue && member.device_id === this._deviceBundle.deviceId) {
        continue
      }

      const recipientFingerprint = member.key_fingerprint || await this._fingerprint(member.encryption_public_key, member.signing_public_key)
      const encrypted_channel_key = await this._encryptForRecipient(member.encryption_public_key, this._channelKeyRaw)
      const signaturePayload = this._keySharePayload({
        keyEpoch,
        recipientUserId: member.user_id,
        recipientDeviceId: member.device_id,
        recipientKeyFingerprint: recipientFingerprint,
        encryptedChannelKey: encrypted_channel_key,
        senderDeviceId: this._deviceBundle.deviceId,
        senderKeyFingerprint: this._deviceBundle.keyFingerprint,
        keyVersion: E2EE_VERSION
      })
      const signature = await this._sign(signaturePayload)

      shares.push({
        recipient_user_id: member.user_id,
        recipient_device_id: member.device_id,
        recipient_key_fingerprint: recipientFingerprint,
        encrypted_channel_key,
        sender_device_id: this._deviceBundle.deviceId,
        sender_key_fingerprint: this._deviceBundle.keyFingerprint,
        signature,
        key_epoch: keyEpoch,
        key_version: E2EE_VERSION
      })
    }

    if (shares.length === 0) return

    await this._request(`/api/v1/channels/${this.channelIdValue}/key_shares`, {
      method: "POST",
      body: JSON.stringify({ key_shares: shares })
    })
  }

  async _fetchMyKeyShare() {
    try {
      return await this._request(`/api/v1/channels/${this.channelIdValue}/key_shares/me?device_id=${encodeURIComponent(this._deviceBundle.deviceId)}`, {
        method: "GET"
      })
    } catch (_error) {
      return null
    }
  }

  async _decryptChannelShare(share) {
    if (share.recipient_device_id && share.recipient_device_id !== this._deviceBundle.deviceId) return null
    if (share.recipient_key_fingerprint && share.recipient_key_fingerprint !== this._deviceBundle.keyFingerprint) return null

    const senderKey = this._memberKeyMap.get(`${share.sender_user_id}:${share.sender_device_id}`)
    if (!senderKey || !senderKey.signing_public_key || !share.signature) return null

    const senderFingerprint = senderKey.key_fingerprint || await this._fingerprint(senderKey.encryption_public_key, senderKey.signing_public_key)
    if (senderFingerprint !== share.sender_key_fingerprint) return null

    const keyEpoch = Number.isInteger(share.key_epoch) ? share.key_epoch : (Number.isInteger(this._keyEpoch) ? this._keyEpoch : 0)
    const keyVersion = share.key_version || E2EE_VERSION
    const payload = this._keySharePayload({
      keyEpoch,
      recipientUserId: share.recipient_user_id || this.currentUserIdValue,
      recipientDeviceId: this._deviceBundle.deviceId,
      recipientKeyFingerprint: share.recipient_key_fingerprint || this._deviceBundle.keyFingerprint,
      encryptedChannelKey: share.encrypted_channel_key,
      senderDeviceId: share.sender_device_id,
      senderKeyFingerprint: share.sender_key_fingerprint,
      keyVersion
    })

    const verified = await this._verifySignature(senderKey.signing_public_key, payload, share.signature)
    if (!verified) return null

    return this._decryptKeyShare(share.encrypted_channel_key)
  }

  async _encryptText(plaintext) {
    const iv = crypto.getRandomValues(new Uint8Array(12))
    const encoded = new TextEncoder().encode(plaintext)
    const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, this._channelKey, encoded)
    const ciphertextBytes = new Uint8Array(ciphertext)
    const combined = new Uint8Array(iv.length + ciphertextBytes.length)
    combined.set(iv, 0)
    combined.set(ciphertextBytes, iv.length)

    return this._bytesToBase64(combined)
  }

  async _computeHmac(encryptedPayload) {
    const key = await crypto.subtle.importKey("raw", this._channelKeyRaw, { name: "HMAC", hash: "SHA-256" }, false, ["sign"])
    const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(encryptedPayload))
    return this._bytesToBase64(new Uint8Array(signature))
  }

  async _decryptVisibleMessages() {
    const nodes = this.element.querySelectorAll('[data-message-content-encoding="e2ee"]')
    for (const node of nodes) {
      await this._decryptMessageNode(node)
    }
  }

  _observeMessages() {
    const container = this.element.querySelector('[data-message-list-target="container"]')
    if (!container) return

    this._observer = new MutationObserver(async (mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (!(node instanceof Element)) continue
          const candidate = node.matches('[data-message-content-encoding="e2ee"]') ? node : node.querySelector('[data-message-content-encoding="e2ee"]')
          if (candidate) await this._decryptMessageNode(candidate)
        }
      }
    })

    this._observer.observe(container, { childList: true, subtree: true })
  }

  async _decryptMessageNode(node) {
    if (node.dataset.e2eeDecrypted === "true") return

    const body = node.querySelector('[data-e2ee-body="true"]')
    if (!body) return
    const contentNode = body.querySelector('[data-e2ee-content="true"]') || body

    const senderFingerprint = node.dataset.messageSenderKeyFingerprint
    if (senderFingerprint && this._blockedFingerprints.has(senderFingerprint)) {
      contentNode.textContent = "[Blocked due to key change]"
      node.dataset.e2eeDecrypted = "true"
      return
    }

    try {
      const encryptedPayload = node.dataset.messageEncryptedContent
      const expectedHmac = node.dataset.messageContentHmac
      if (!encryptedPayload) throw new Error("Missing encrypted payload")

      if (expectedHmac) {
        const computed = await this._computeHmac(encryptedPayload)
        if (computed !== expectedHmac) throw new Error("HMAC verification failed")
      }

      const combined = this._base64ToBytes(encryptedPayload)
      if (combined.length <= 12) throw new Error("Encrypted payload too short")
      const iv = combined.slice(0, 12)
      const ciphertext = combined.slice(12)
      const plaintextBytes = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, this._channelKey, ciphertext)
      contentNode.textContent = new TextDecoder().decode(plaintextBytes)
    } catch (error) {
      console.error("Failed to decrypt message", error)
      contentNode.textContent = "[Unable to decrypt]"
    }

    node.dataset.e2eeDecrypted = "true"
  }

  async _encryptForRecipient(recipientPublicKeyBase64, rawChannelKey) {
    const recipientPublicKey = await this._importX25519Public(recipientPublicKeyBase64)
    const ephemeralKeys = await this._generateKeyPair("X25519", ["deriveBits"])
    const ephemeralPublic = new Uint8Array(await crypto.subtle.exportKey("raw", ephemeralKeys.publicKey))
    const wrapKey = await this._deriveWrapKey(ephemeralKeys.privateKey, recipientPublicKey, ["encrypt"])

    const iv = crypto.getRandomValues(new Uint8Array(12))
    const ciphertext = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, wrapKey, rawChannelKey))
    const combined = new Uint8Array(ephemeralPublic.length + iv.length + ciphertext.length)
    combined.set(ephemeralPublic, 0)
    combined.set(iv, ephemeralPublic.length)
    combined.set(ciphertext, ephemeralPublic.length + iv.length)

    return this._bytesToBase64(combined)
  }

  async _decryptKeyShare(encryptedBlob) {
    const combined = this._base64ToBytes(encryptedBlob)
    if (combined.length < 32 + 12 + 16) throw new Error("Key share payload too short")

    const ephemeralPublicBytes = combined.slice(0, 32)
    const iv = combined.slice(32, 44)
    const ciphertext = combined.slice(44)
    const ephemeralPublicKey = await this._importX25519Public(this._bytesToBase64(ephemeralPublicBytes))
    const wrapKey = await this._deriveWrapKey(this._deviceBundle.encryptionPrivateCryptoKey, ephemeralPublicKey, ["decrypt"])
    return new Uint8Array(await crypto.subtle.decrypt({ name: "AES-GCM", iv }, wrapKey, ciphertext))
  }

  async _deriveWrapKey(privateKey, publicKey, usages) {
    const sharedBits = await crypto.subtle.deriveBits({ name: "X25519", public: publicKey }, privateKey, 256)
    const keyMaterial = await crypto.subtle.importKey("raw", sharedBits, "HKDF", false, ["deriveKey"])
    return crypto.subtle.deriveKey(
      {
        name: "HKDF",
        hash: "SHA-256",
        salt: new TextEncoder().encode(KEY_SHARE_WRAP_SALT),
        info: new Uint8Array()
      },
      keyMaterial,
      { name: "AES-GCM", length: 256 },
      false,
      usages
    )
  }

  async _sign(payload) {
    const signature = await crypto.subtle.sign(
      { name: "Ed25519" },
      this._deviceBundle.signingPrivateCryptoKey,
      new TextEncoder().encode(payload)
    )

    return this._bytesToBase64(new Uint8Array(signature))
  }

  async _verifySignature(signingPublicKeyBase64, payload, signatureBase64) {
    const publicKey = await this._importEd25519Public(signingPublicKeyBase64, ["verify"])
    return crypto.subtle.verify(
      { name: "Ed25519" },
      publicKey,
      this._base64ToBytes(signatureBase64),
      new TextEncoder().encode(payload)
    )
  }

  async _fingerprint(encryptionPublicKeyBase64, signingPublicKeyBase64) {
    const canonical = `${encryptionPublicKeyBase64}|${signingPublicKeyBase64}`
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical))
    return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("")
  }

  _keySharePayload({ keyEpoch, recipientUserId, recipientDeviceId, recipientKeyFingerprint, encryptedChannelKey, senderDeviceId, senderKeyFingerprint, keyVersion }) {
    return [
      KEY_SHARE_PREFIX,
      this.channelIdValue,
      keyEpoch,
      recipientUserId,
      recipientDeviceId,
      recipientKeyFingerprint,
      encryptedChannelKey,
      senderDeviceId,
      senderKeyFingerprint,
      keyVersion
    ].map((value) => value?.toString() || "").join(":")
  }

  async _generateKeyPair(name, usages) {
    return crypto.subtle.generateKey({ name }, false, usages)
  }

  async _importX25519Private(privateKeyBase64) {
    return crypto.subtle.importKey("pkcs8", this._base64ToBytes(privateKeyBase64), { name: "X25519" }, true, ["deriveBits"])
  }

  async _importX25519Public(publicKeyBase64) {
    return crypto.subtle.importKey("raw", this._base64ToBytes(publicKeyBase64), { name: "X25519" }, true, [])
  }

  async _importEd25519Private(privateKeyBase64) {
    return crypto.subtle.importKey("pkcs8", this._base64ToBytes(privateKeyBase64), { name: "Ed25519" }, true, ["sign"])
  }

  async _importEd25519Public(publicKeyBase64, usages = []) {
    return crypto.subtle.importKey("raw", this._base64ToBytes(publicKeyBase64), { name: "Ed25519" }, true, usages)
  }

  _loadPins() {
    try {
      return JSON.parse(localStorage.getItem(TOFU_PINS_KEY) || "{}")
    } catch (_error) {
      return {}
    }
  }

  _channelStorageKey() {
    return `${CHANNEL_KEY_PREFIX}${this.channelIdValue}`
  }

  async _request(url, options) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      ["X-HomeChat-E2EE-Version"]: E2EE_VERSION,
      ["X-HomeChat-Device-Id"]: this._deviceBundle?.deviceId || "",
      ...options?.headers
    }

    if (csrfToken) headers["X-CSRF-Token"] = csrfToken

    const response = await fetch(url, {
      credentials: "same-origin",
      ...options,
      headers
    })

    const json = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new Error(json.error || `Request failed: ${response.status}`)
    }

    return json
  }

  _required() {
    return this.channelTypeValue === "private" || this.channelTypeValue === "dm"
  }

  _removeLegacyKeyMaterial() {
    localStorage.removeItem(LEGACY_DEVICE_BUNDLE_KEY)
    localStorage.removeItem(DEVICE_BUNDLE_KEY)
    const keys = []
    for (let i = 0; i < localStorage.length; i += 1) {
      const key = localStorage.key(i)
      if (key && (key.startsWith(LEGACY_CHANNEL_KEY_PREFIX) || key.startsWith(CHANNEL_KEY_PREFIX))) {
        keys.push(key)
      }
    }
    keys.forEach((key) => localStorage.removeItem(key))
  }

  async _openKeyDatabase() {
    if (this._keyDbPromise) return this._keyDbPromise
    if (!window.indexedDB) throw new Error("IndexedDB is required for E2EE key storage")

    this._keyDbPromise = new Promise((resolve, reject) => {
      const request = window.indexedDB.open(KEY_DB_NAME, KEY_DB_VERSION)
      request.onupgradeneeded = () => {
        const db = request.result
        if (!db.objectStoreNames.contains(KEY_STORE_NAME)) {
          db.createObjectStore(KEY_STORE_NAME)
        }
      }
      request.onsuccess = () => resolve(request.result)
      request.onerror = () => reject(request.error || new Error("Could not open E2EE key store"))
      request.onblocked = () => reject(new Error("E2EE key store upgrade was blocked"))
    })

    return this._keyDbPromise
  }

  async _idbGet(key) {
    const db = await this._openKeyDatabase()
    return new Promise((resolve, reject) => {
      const request = db.transaction(KEY_STORE_NAME, "readonly").objectStore(KEY_STORE_NAME).get(key)
      request.onsuccess = () => resolve(request.result)
      request.onerror = () => reject(request.error || new Error("Could not read E2EE key store"))
    })
  }

  async _idbSet(key, value) {
    const db = await this._openKeyDatabase()
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(KEY_STORE_NAME, "readwrite")
      transaction.objectStore(KEY_STORE_NAME).put(value, key)
      transaction.oncomplete = () => resolve()
      transaction.onerror = () => reject(transaction.error || new Error("Could not write E2EE key store"))
      transaction.onabort = () => reject(transaction.error || new Error("E2EE key store write was aborted"))
    })
  }

  async _idbDelete(key) {
    const db = await this._openKeyDatabase()
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(KEY_STORE_NAME, "readwrite")
      transaction.objectStore(KEY_STORE_NAME).delete(key)
      transaction.oncomplete = () => resolve()
      transaction.onerror = () => reject(transaction.error || new Error("Could not delete E2EE key store entry"))
      transaction.onabort = () => reject(transaction.error || new Error("E2EE key store delete was aborted"))
    })
  }

  _bytesFromStoredValue(value) {
    if (value instanceof Uint8Array) return value
    if (value instanceof ArrayBuffer) return new Uint8Array(value)
    if (Array.isArray(value)) return new Uint8Array(value)
    if (typeof value === "string") return this._base64ToBytes(value)
    throw new Error("Stored E2EE key material has an invalid format")
  }

  _bytesToBase64(bytes) {
    let binary = ""
    bytes.forEach((b) => {
      binary += String.fromCharCode(b)
    })
    return btoa(binary)
  }

  _base64ToBytes(base64) {
    const binary = atob(base64)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i)
    }
    return bytes
  }

  _notify(message) {
    const event = new CustomEvent("homechat:e2ee-warning", { detail: { message } })
    document.dispatchEvent(event)
    console.warn(message)
  }
}
