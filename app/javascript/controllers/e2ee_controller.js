import { Controller } from "@hotwired/stimulus"

const DEVICE_BUNDLE_KEY = "homechat_e2ee_device_bundle_v1"
const TOFU_PINS_KEY = "homechat_e2ee_tofu_pins_v1"
const CHANNEL_KEY_PREFIX = "homechat_e2ee_channel_key_"
const E2EE_VERSION = "1"
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

    try {
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
    const existing = localStorage.getItem(DEVICE_BUNDLE_KEY)
    if (existing) {
      const parsed = JSON.parse(existing)
      this._deviceBundle = await this._importDeviceBundle(parsed)
      return
    }

    const encryptionKeys = await crypto.subtle.generateKey(
      { name: "ECDH", namedCurve: "P-256" },
      true,
      ["deriveBits"]
    )

    const signingKeys = await crypto.subtle.generateKey(
      { name: "ECDSA", namedCurve: "P-256" },
      true,
      ["sign", "verify"]
    )

    const encryptionPrivateJwk = await crypto.subtle.exportKey("jwk", encryptionKeys.privateKey)
    const encryptionPublicJwk = await crypto.subtle.exportKey("jwk", encryptionKeys.publicKey)
    const signingPrivateJwk = await crypto.subtle.exportKey("jwk", signingKeys.privateKey)
    const signingPublicJwk = await crypto.subtle.exportKey("jwk", signingKeys.publicKey)

    const fingerprint = await this._fingerprint(encryptionPublicJwk, signingPublicJwk)

    const serializable = {
      deviceId: (crypto.randomUUID ? crypto.randomUUID() : `device-${Date.now()}`),
      encryptionPrivateJwk,
      encryptionPublicJwk,
      signingPrivateJwk,
      signingPublicJwk,
      keyFingerprint: fingerprint
    }

    localStorage.setItem(DEVICE_BUNDLE_KEY, JSON.stringify(serializable))
    this._deviceBundle = await this._importDeviceBundle(serializable)
  }

  async _importDeviceBundle(serialized) {
    const encryptionPrivateKey = await crypto.subtle.importKey(
      "jwk",
      serialized.encryptionPrivateJwk,
      { name: "ECDH", namedCurve: "P-256" },
      true,
      ["deriveBits"]
    )

    const encryptionPublicKey = await crypto.subtle.importKey(
      "jwk",
      serialized.encryptionPublicJwk,
      { name: "ECDH", namedCurve: "P-256" },
      true,
      []
    )

    const signingPrivateKey = await crypto.subtle.importKey(
      "jwk",
      serialized.signingPrivateJwk,
      { name: "ECDSA", namedCurve: "P-256" },
      true,
      ["sign"]
    )

    const signingPublicKey = await crypto.subtle.importKey(
      "jwk",
      serialized.signingPublicJwk,
      { name: "ECDSA", namedCurve: "P-256" },
      true,
      ["verify"]
    )

    return {
      ...serialized,
      encryptionPrivateKey,
      encryptionPublicKey,
      signingPrivateKey,
      signingPublicKey
    }
  }

  async _publishKeyBundle() {
    await this._request("/api/v1/me/e2ee_key", {
      method: "PUT",
      body: JSON.stringify({
        device_id: this._deviceBundle.deviceId,
        encryption_public_key: JSON.stringify(this._deviceBundle.encryptionPublicJwk),
        signing_public_key: JSON.stringify(this._deviceBundle.signingPublicJwk),
        key_fingerprint: this._deviceBundle.keyFingerprint,
        key_version: E2EE_VERSION
      })
    })
  }

  async _refreshMemberKeys() {
    const result = await this._request(`/api/v1/channels/${this.channelIdValue}/e2ee_keys`, {
      method: "GET"
    })

    const pins = this._loadPins()
    const members = Array.isArray(result.members) ? result.members : []

    members.forEach((member) => {
      const pinKey = `${member.user_id}:${member.device_id}`
      const existingFingerprint = pins[pinKey]
      if (!existingFingerprint) {
        pins[pinKey] = member.key_fingerprint
      } else if (existingFingerprint !== member.key_fingerprint) {
        this._blockedFingerprints.add(member.key_fingerprint)
      }

      this._memberKeyMap.set(pinKey, member)
    })

    localStorage.setItem(TOFU_PINS_KEY, JSON.stringify(pins))
  }

  async _ensureChannelKey() {
    if (this._channelKey) return

    const stored = localStorage.getItem(this._channelStorageKey())
    if (stored) {
      const raw = this._base64ToBytes(stored)
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
        localStorage.setItem(this._channelStorageKey(), this._bytesToBase64(decryptedRaw))
        return
      }
    }

    this._channelKeyRaw = crypto.getRandomValues(new Uint8Array(32))
    this._channelKey = await crypto.subtle.importKey("raw", this._channelKeyRaw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"])
    localStorage.setItem(this._channelStorageKey(), this._bytesToBase64(this._channelKeyRaw))
    await this._shareChannelKeyWithMembers()
  }

  async _shareChannelKeyWithMembers() {
    const shares = []

    for (const member of this._memberKeyMap.values()) {
      if (member.user_id === this.currentUserIdValue && member.device_id === this._deviceBundle.deviceId) {
        continue
      }

      const encrypted_channel_key = await this._encryptForRecipient(member.encryption_public_key, this._channelKeyRaw)
      const signaturePayload = JSON.stringify({
        channel_id: this.channelIdValue,
        recipient_user_id: member.user_id,
        recipient_device_id: member.device_id,
        encrypted_channel_key
      })
      const signature = await this._sign(signaturePayload)

      shares.push({
        recipient_user_id: member.user_id,
        recipient_device_id: member.device_id,
        encrypted_channel_key,
        sender_device_id: this._deviceBundle.deviceId,
        sender_key_fingerprint: this._deviceBundle.keyFingerprint,
        signature,
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
    const senderKey = this._memberKeyMap.get(`${share.sender_user_id}:${share.sender_device_id}`)
    if (!senderKey) return null

    return this._decryptFromSender(senderKey.encryption_public_key, share.encrypted_channel_key)
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

      let iv
      let ciphertext
      if (encryptedPayload.trim().startsWith("{")) {
        const parsed = JSON.parse(encryptedPayload)
        iv = this._base64ToBytes(parsed.iv)
        ciphertext = this._base64ToBytes(parsed.ciphertext)
      } else {
        const combined = this._base64ToBytes(encryptedPayload)
        if (combined.length <= 12) throw new Error("Encrypted payload too short")
        iv = combined.slice(0, 12)
        ciphertext = combined.slice(12)
      }
      const plaintextBytes = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, this._channelKey, ciphertext)
      contentNode.textContent = new TextDecoder().decode(plaintextBytes)
    } catch (error) {
      console.error("Failed to decrypt message", error)
      contentNode.textContent = "[Unable to decrypt]"
    }

    node.dataset.e2eeDecrypted = "true"
  }

  async _encryptForRecipient(recipientPublicKeyJson, rawChannelKey) {
    const recipientPublicJwk = JSON.parse(recipientPublicKeyJson)
    const recipientPublicKey = await crypto.subtle.importKey(
      "jwk",
      recipientPublicJwk,
      { name: "ECDH", namedCurve: "P-256" },
      true,
      []
    )

    const sharedBits = await crypto.subtle.deriveBits({ name: "ECDH", public: recipientPublicKey }, this._deviceBundle.encryptionPrivateKey, 256)
    const wrapKeyMaterial = await crypto.subtle.digest("SHA-256", sharedBits)
    const wrapKey = await crypto.subtle.importKey("raw", wrapKeyMaterial, { name: "AES-GCM" }, false, ["encrypt"])

    const iv = crypto.getRandomValues(new Uint8Array(12))
    const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, wrapKey, rawChannelKey)

    return JSON.stringify({ iv: this._bytesToBase64(iv), ciphertext: this._bytesToBase64(new Uint8Array(ciphertext)) })
  }

  async _decryptFromSender(senderPublicKeyJson, encryptedBlob) {
    const senderPublicJwk = JSON.parse(senderPublicKeyJson)
    const senderPublicKey = await crypto.subtle.importKey(
      "jwk",
      senderPublicJwk,
      { name: "ECDH", namedCurve: "P-256" },
      true,
      []
    )

    const parsed = JSON.parse(encryptedBlob)
    const iv = this._base64ToBytes(parsed.iv)
    const ciphertext = this._base64ToBytes(parsed.ciphertext)

    const sharedBits = await crypto.subtle.deriveBits({ name: "ECDH", public: senderPublicKey }, this._deviceBundle.encryptionPrivateKey, 256)
    const wrapKeyMaterial = await crypto.subtle.digest("SHA-256", sharedBits)
    const wrapKey = await crypto.subtle.importKey("raw", wrapKeyMaterial, { name: "AES-GCM" }, false, ["decrypt"])
    const decrypted = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, wrapKey, ciphertext)

    return new Uint8Array(decrypted)
  }

  async _sign(payload) {
    const signature = await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      this._deviceBundle.signingPrivateKey,
      new TextEncoder().encode(payload)
    )

    return this._bytesToBase64(new Uint8Array(signature))
  }

  async _fingerprint(encryptionPublicJwk, signingPublicJwk) {
    const canonical = `${this._stableJson(encryptionPublicJwk)}|${this._stableJson(signingPublicJwk)}`
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical))
    return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("")
  }

  _stableJson(value) {
    if (Array.isArray(value)) return `[${value.map((v) => this._stableJson(v)).join(",")}]`
    if (value && typeof value === "object") {
      return `{${Object.keys(value).sort().map((k) => `${JSON.stringify(k)}:${this._stableJson(value[k])}`).join(",")}}`
    }
    return JSON.stringify(value)
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
