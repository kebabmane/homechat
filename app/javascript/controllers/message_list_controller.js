import { Controller } from "@hotwired/stimulus"
import { subscribeToTyping, broadcastTyping, unsubscribeTyping } from "channels/typing_channel"

const MESSAGE_QUEUE_KEY = 'homechat_message_queue'

// Manages channel message area interactions: scroll, header shadow, textarea autosize, offline queueing.
export default class extends Controller {
  static targets = ["container", "header", "textarea", "scrollButton", "typingIndicator", "offlineIndicator", "sendButton", "composerArea"]
  static values = {
    autoscroll: { type: Boolean, default: true },
    autofocus: { type: Boolean, default: true },
    currentUser: String,
    channelId: String,
    channelType: String
  }

  connect() {
    this._typingTimers = new Map()
    this._typingUsers = new Map()
    this._typingContainerEl = this.hasTypingIndicatorTarget ? this.typingIndicatorTarget : null
    this._draftSaveTimer = null
    this._isOnline = navigator.onLine

    // Get current username for message styling
    const currentUser = this.hasCurrentUserValue ? this.currentUserValue : (document.querySelector('[data-current-username]')?.dataset.currentUsername || null)
    this._currentUsername = currentUser ? currentUser.toLowerCase() : null

    // Setup offline/online listeners
    this._onOnline = () => this._handleOnline()
    this._onOffline = () => this._handleOffline()
    window.addEventListener('online', this._onOnline)
    window.addEventListener('offline', this._onOffline)

    // Listen for sync messages from service worker
    this._onSwMessage = (event) => {
      if (event.data?.type === 'SYNC_MESSAGES') {
        this._syncQueuedMessages()
      }
    }
    navigator.serviceWorker?.addEventListener('message', this._onSwMessage)

    // Update offline indicator on connect
    this._updateOfflineIndicator()

    // Track new messages that arrive while scrolled up
    this._newMessagesBelow = false

    // Style existing messages on page load
    this._styleAllMessages()

    // Ensure newest messages are visible when desired
    if (this.autoscrollValue) {
      requestAnimationFrame(() => this._scrollToBottom(true))
    }

    // Header shadow on scroll
    if (this.hasContainerTarget) {
      this._onScroll = () => {
        this.updateHeaderShadow()
        this.updateScrollButton()
      }
      this.containerTarget.addEventListener("scroll", this._onScroll)
      this.updateHeaderShadow()
      this.updateScrollButton()

      // Watch for new messages being appended
      this._observer = new MutationObserver((mutations) => {
        let shouldScroll = false
        const processNode = (node) => {
          if (!node) return
          if (node.nodeType === Node.ELEMENT_NODE) {
            this._handleNewMessageNode(node)
            this._styleMessage(node)
            shouldScroll = true
          } else if (node.nodeType === Node.DOCUMENT_FRAGMENT_NODE) {
            node.childNodes.forEach(processNode)
          }
        }

        mutations.forEach((mutation) => {
          mutation.addedNodes.forEach(processNode)
        })

        if (shouldScroll) {
          if (this.autoscrollValue) {
            this._scrollToBottom(true)
          } else {
            this._setNewMessagesBelow(true)
            this.updateScrollButton()
          }
        }
      })
      this._observer.observe(this.containerTarget, { childList: true, subtree: true })
    }

    // Subscribe to typing events for this channel (read from data-channel-id on root)
    const channelId = this.element?.dataset.channelId
    if (channelId) {
      subscribeToTyping(channelId, currentUser, (data) => this.showTyping(data))
      this._typingChannelId = channelId
    }

    // Autosize composer and restore draft
    if (this.hasTextareaTarget) {
      this._restoreDraft()
      this.autoResize()
      if (this.autofocusValue && this._shouldAutofocus()) {
        this.textareaTarget.focus()
      }
      this._onTextareaBlur = () => {
        if (this._typingChannelId) {
          broadcastTyping(this._typingChannelId, false)
        }
        this._saveDraft()
      }
      this.textareaTarget.addEventListener('blur', this._onTextareaBlur)
    }

    // Mobile keyboard handling using visualViewport API
    this._setupMobileKeyboardHandling()
  }

  // Mobile keyboard detection and layout adjustment
  _setupMobileKeyboardHandling() {
    // Only on mobile devices and if visualViewport is available
    if (!window.visualViewport || this._isDesktop()) return

    this._initialViewportHeight = window.visualViewport.height
    this._keyboardVisible = false

    this._onViewportResize = () => {
      const currentHeight = window.visualViewport.height
      const heightDiff = this._initialViewportHeight - currentHeight

      // Keyboard is likely open if viewport shrunk by more than 150px
      const keyboardOpen = heightDiff > 150

      if (keyboardOpen && !this._keyboardVisible) {
        this._onKeyboardShow(heightDiff)
      } else if (!keyboardOpen && this._keyboardVisible) {
        this._onKeyboardHide()
      }
    }

    window.visualViewport.addEventListener('resize', this._onViewportResize)

    // Also handle scroll events on visualViewport (iOS Safari)
    this._onViewportScroll = () => {
      if (this._keyboardVisible) {
        this._adjustForKeyboard()
      }
    }
    window.visualViewport.addEventListener('scroll', this._onViewportScroll)
  }

  _isDesktop() {
    return window.matchMedia('(min-width: 768px)').matches
  }

  _shouldAutofocus() {
    // Avoid forcing the software keyboard open on mobile.
    return this._isDesktop()
  }

  _onKeyboardShow(keyboardHeight) {
    this._keyboardVisible = true
    this._keyboardHeight = keyboardHeight

    // Add class for CSS-based adjustments
    this.element.classList.add('keyboard-visible')

    // Adjust the layout
    this._adjustForKeyboard()

    // Scroll to bottom to keep messages visible
    requestAnimationFrame(() => {
      this._scrollToBottom(true)
    })
  }

  _onKeyboardHide() {
    this._keyboardVisible = false
    this._keyboardHeight = 0

    // Remove keyboard class
    this.element.classList.remove('keyboard-visible')

    // Reset any inline styles
    if (this.hasComposerAreaTarget) {
      this.composerAreaTarget.style.transform = ''
      this.composerAreaTarget.style.position = ''
    }

    // Reset container padding
    if (this.hasContainerTarget) {
      this.containerTarget.style.paddingBottom = ''
    }
  }

  _adjustForKeyboard() {
    if (!this._keyboardVisible || !window.visualViewport) return

    // On iOS Safari, the viewport can scroll behind fixed elements
    // We need to adjust for this offset
    const offsetTop = window.visualViewport.offsetTop

    if (this.hasComposerAreaTarget && offsetTop > 0) {
      // Translate the composer to stay visible
      this.composerAreaTarget.style.transform = `translateY(${-offsetTop}px)`
    }

    // Ensure messages area accounts for keyboard
    if (this.hasContainerTarget) {
      // Add extra padding to keep content from being hidden behind composer
      const extraPadding = this._keyboardHeight > 0 ? 60 : 0
      this.containerTarget.style.paddingBottom = `${extraPadding}px`
    }
  }

  disconnect() {
    if (this._onScroll && this.hasContainerTarget) {
      this.containerTarget.removeEventListener("scroll", this._onScroll)
    }
    if (this._observer) {
      this._observer.disconnect()
      this._observer = null
    }
    if (this._typingTimers) {
      this._typingTimers.forEach((timer) => clearTimeout(timer))
      this._typingTimers.clear()
    }
    if (this._typingUsers) {
      this._typingUsers.clear()
      this._updateHeaderTypingStatus()
    }
    if (this._draftSaveTimer) {
      clearTimeout(this._draftSaveTimer)
      this._draftSaveTimer = null
    }
    // Save draft before disconnecting
    this._saveDraft()
    if (this._typingChannelId) {
      broadcastTyping(this._typingChannelId, false)
    }
    if (this._onTextareaBlur && this.hasTextareaTarget) {
      this.textareaTarget.removeEventListener('blur', this._onTextareaBlur)
      this._onTextareaBlur = null
    }
    // Remove offline/online listeners
    window.removeEventListener('online', this._onOnline)
    window.removeEventListener('offline', this._onOffline)
    navigator.serviceWorker?.removeEventListener('message', this._onSwMessage)

    // Remove visualViewport listeners
    if (window.visualViewport) {
      if (this._onViewportResize) {
        window.visualViewport.removeEventListener('resize', this._onViewportResize)
      }
      if (this._onViewportScroll) {
        window.visualViewport.removeEventListener('scroll', this._onViewportScroll)
      }
    }
    this._keyboardVisible = false

    unsubscribeTyping()
    this._typingChannelId = null
    this._currentUsername = null
    this._typingContainerEl = null
  }

  // Called before form submission to show loading state
  beforeSubmit(event) {
    if (event.defaultPrevented) return
    if (!this.hasSendButtonTarget) return
    const btn = this.sendButtonTarget
    btn.disabled = true
    this._sendButtonOriginalHTML = btn.innerHTML
    this._sendButtonOriginalClasses = btn.className
    btn.innerHTML = `
      <svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24" aria-hidden="true">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
      </svg>
    `
    btn.classList.add('opacity-80', 'cursor-not-allowed')
  }

  // Called on turbo:submit-end from the form
  afterSubmit(event) {
    // Check if submission was successful (Turbo provides detail.success)
    const success = event?.detail?.success !== false

    if (this.hasTextareaTarget) {
      this.textareaTarget.value = ""
      this.autoResize()
      this.textareaTarget.focus()
    }

    // Restore button from loading state before showing confirmation
    this._restoreSendButton()

    // Show send confirmation feedback
    if (success) {
      this._showSendConfirmation()
    }

    // Clear draft after successful submit
    this._clearDraft()
    if (this._typingChannelId) {
      broadcastTyping(this._typingChannelId, false)
      if (this._currentUsername) {
        this._removeTypingIndicator(this._currentUsername)
      }
    }
    requestAnimationFrame(() => this._scrollToBottom(true))
  }

  _restoreSendButton() {
    if (!this.hasSendButtonTarget) return
    const btn = this.sendButtonTarget
    btn.disabled = false
    if (this._sendButtonOriginalHTML) {
      btn.innerHTML = this._sendButtonOriginalHTML
      this._sendButtonOriginalHTML = null
    }
    if (this._sendButtonOriginalClasses) {
      btn.className = this._sendButtonOriginalClasses
      this._sendButtonOriginalClasses = null
    }
    btn.classList.remove('opacity-80', 'cursor-not-allowed')
  }

  // Show brief visual feedback after sending a message
  _showSendConfirmation() {
    if (!this.hasSendButtonTarget) return

    const btn = this.sendButtonTarget
    const originalHTML = btn.innerHTML
    const originalClasses = btn.className

    // Briefly show checkmark with success styling
    btn.innerHTML = `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
      </svg>
    `
    btn.classList.remove('bg-blue-600', 'hover:bg-blue-700')
    btn.classList.add('bg-green-500', 'scale-105')

    // Add subtle pulse animation
    btn.style.transition = 'transform 150ms ease-out, background-color 150ms ease-out'

    // Restore original state after brief delay
    setTimeout(() => {
      btn.innerHTML = originalHTML
      btn.className = originalClasses
      btn.style.transition = ''
    }, 600)
  }

  submit(event) {
    // Submit on Enter, allow Shift+Enter for newline
    const enterPref = this.enterToSend()
    if (!enterPref) return // ignore Enter; user prefers manual send
    if (event.shiftKey) return
    event.preventDefault()
    let form = event.target.form
    if (!form) {
      form = event.target.closest('form') || this.element.closest('form')
    }
    if (form) form.requestSubmit()
  }

  enterToSend() {
    const val = window.localStorage.getItem('enterToSend')
    return val === null ? true : val !== 'false'
  }

  escape(event) {
    if (!this.hasTextareaTarget) return
    this.textareaTarget.blur()
  }

  editLastMessage(event) {
    if (event.defaultPrevented) return
    if (!this.hasTextareaTarget) return
    if (this.textareaTarget.value.trim() !== '') return

    event.preventDefault()

    const lastOwn = this._findLastOwnMessage()
    if (!lastOwn) return

    const messageId = lastOwn.dataset.messageId
    const frame = document.getElementById(`message_${messageId}`)
    if (!frame) return

    // Skip encrypted messages
    if (lastOwn.dataset.messageContentEncoding === 'e2ee') return

    const channelId = this.hasChannelIdValue ? this.channelIdValue : this.element?.dataset.channelId
    if (!channelId) return

    frame.src = `/channels/${channelId}/messages/${messageId}/edit`
  }

  _findLastOwnMessage() {
    if (!this._currentUsername || !this.hasContainerTarget) return null
    const ownMessages = this.containerTarget.querySelectorAll(`[data-message-username="${this._currentUsername}"]`)
    if (ownMessages.length === 0) return null
    return ownMessages[ownMessages.length - 1]
  }

  autoResize() {
    if (!this.hasTextareaTarget) return
    const ta = this.textareaTarget
    ta.style.height = "auto"
    ta.style.height = Math.min(ta.scrollHeight, window.innerHeight * 0.4) + "px"
    this.debouncedBroadcastTyping()
    this.debouncedSaveDraft()
  }

  scrollToBottom(arg = false) {
    if (arg instanceof Event) {
      arg.preventDefault()
      this._scrollToBottom(true)
      this._setNewMessagesBelow(false)
      return
    }
    this._scrollToBottom(Boolean(arg))
    this._setNewMessagesBelow(false)
  }

  updateHeaderShadow() {
    if (!this.hasHeaderTarget || !this.hasContainerTarget) return
    const scrolled = this.containerTarget.scrollTop > 0
    this.headerTarget.classList.toggle("shadow-sm", scrolled)
  }

  updateScrollButton() {
    if (!this.hasContainerTarget) return
    if (!this.hasScrollButtonTarget) return
    const nearBottom = this._isNearBottom()
    this.scrollButtonTarget.classList.toggle("hidden", nearBottom)
    this.scrollButtonTarget.classList.toggle("inline-flex", !nearBottom)
    this.autoscrollValue = nearBottom
    if (nearBottom) {
      this._setNewMessagesBelow(false)
    }
  }

  _setNewMessagesBelow(hasNew) {
    if (!this.hasScrollButtonTarget) return
    this._newMessagesBelow = hasNew
    this.scrollButtonTarget.classList.toggle("has-new-messages", hasNew)
  }

  showTyping({ username, typing }) {
    if (!username) return
    const key = username.toLowerCase()
    if (this._currentUsername && key === this._currentUsername) return
    const container = this._typingContainer()
    if (!container) return

    if (typing === false) {
      this._removeTypingIndicator(key)
      return
    }

    this._typingUsers.set(key, username)
    this._updateHeaderTypingStatus()

    let indicator = container.querySelector(`[data-typing-username="${key}"]`)
    if (!indicator) {
      indicator = this._buildTypingIndicator(username, key)
      container.appendChild(indicator)
    }

    indicator.classList.remove('hidden')

    if (this._typingTimers.has(key)) {
      clearTimeout(this._typingTimers.get(key))
    }

    const timer = setTimeout(() => this._removeTypingIndicator(key), 1800)
    this._typingTimers.set(key, timer)

    if (this.autoscrollValue) {
      this._scrollToBottom(false)
    }
  }

  debouncedBroadcastTyping = (() => {
    let last = 0
    return () => {
      const now = Date.now()
      if (now - last < 800) return
      last = now
      if (this._typingChannelId) {
        broadcastTyping(this._typingChannelId, true)
      }
    }
  })()

  _scrollToBottom(force = false) {
    if (!this.hasContainerTarget) return
    const el = this.containerTarget
    if (!force && !this.autoscrollValue) return
    el.scrollTop = el.scrollHeight
    this.updateScrollButton()
  }

  _isNearBottom(threshold = 96) {
    if (!this.hasContainerTarget) return true
    const el = this.containerTarget
    return el.scrollHeight - el.scrollTop - el.clientHeight < threshold
  }

  _typingContainer(createIfMissing = true) {
    if (this._typingContainerEl && document.body.contains(this._typingContainerEl)) {
      return this._typingContainerEl
    }
    if (this.hasTypingIndicatorTarget) {
      this._typingContainerEl = this.typingIndicatorTarget
      return this._typingContainerEl
    }
    if (!createIfMissing || !this.hasContainerTarget) return null
    const el = document.createElement('div')
    el.dataset.messageListTarget = 'typingIndicator'
    el.className = 'space-y-3 pb-6'
    this.containerTarget.appendChild(el)
    this._typingContainerEl = el
    return el
  }

  _buildTypingIndicator(username, key) {
    const safeName = (username || '').trim() || username || 'User'
    const initial = safeName.charAt(0).toUpperCase() || '?'
    const wrapper = document.createElement('div')
    wrapper.className = 'flex items-start gap-3 sm:gap-4 opacity-90'
    wrapper.dataset.typingUsername = key

    // Avatar container
    const avatar = document.createElement('div')
    avatar.className = 'flex-shrink-0'

    const avatarCircle = document.createElement('div')
    avatarCircle.className = 'h-9 w-9 rounded-full bg-gray-200 text-gray-600 flex items-center justify-center font-semibold'
    avatarCircle.textContent = initial
    avatar.appendChild(avatarCircle)

    // Body container
    const body = document.createElement('div')
    body.className = 'flex-1 min-w-0'

    const headerDiv = document.createElement('div')
    headerDiv.className = 'flex items-center gap-2 mb-1'

    const usernameSpan = document.createElement('span')
    usernameSpan.className = 'font-semibold text-gray-900 truncate'
    usernameSpan.textContent = safeName  // Safe - uses textContent instead of innerHTML

    const typingSpan = document.createElement('span')
    typingSpan.className = 'text-xs text-gray-400'
    typingSpan.textContent = 'typing…'

    headerDiv.appendChild(usernameSpan)
    headerDiv.appendChild(typingSpan)

    // Typing indicator dots with staggered animation
    const dotsContainer = document.createElement('div')
    dotsContainer.className = 'inline-flex items-center gap-1.5 rounded-full bg-gray-100 px-3 py-2 text-xs text-gray-600'

    const srSpan = document.createElement('span')
    srSpan.className = 'sr-only'
    srSpan.textContent = 'Typing'
    dotsContainer.appendChild(srSpan)

    for (let i = 0; i < 3; i++) {
      const dot = document.createElement('span')
      dot.className = 'typing-dot w-2 h-2 rounded-full bg-gray-400'
      dotsContainer.appendChild(dot)
    }

    body.appendChild(headerDiv)
    body.appendChild(dotsContainer)

    wrapper.appendChild(avatar)
    wrapper.appendChild(body)
    return wrapper
  }

  _removeTypingIndicator(key) {
    if (!this._typingTimers) return
    if (this._typingTimers.has(key)) {
      clearTimeout(this._typingTimers.get(key))
      this._typingTimers.delete(key)
    }
    if (this._typingUsers) {
      this._typingUsers.delete(key)
      this._updateHeaderTypingStatus()
    }
    const container = this._typingContainer(false)
    if (!container) return
    const indicator = container.querySelector(`[data-typing-username="${key}"]`)
    if (indicator) {
      indicator.remove()
      if (!container.hasChildNodes()) {
        container.remove()
        this._typingContainerEl = null
      }
    }
  }

  _updateHeaderTypingStatus() {
    if (!this.hasHeaderTarget) return

    let status = this.headerTarget.querySelector('[data-message-list-header-typing]')
    const names = Array.from(this._typingUsers?.values() || []).filter(Boolean)

    if (names.length === 0) {
      status?.remove()
      return
    }

    if (!status) {
      status = document.createElement('span')
      status.dataset.messageListHeaderTyping = 'true'
      status.className = 'hidden shrink-0 text-xs font-medium text-amber-700 sm:inline'
      this.headerTarget.appendChild(status)
    }

    const visibleNames = names.slice(0, 2).join(', ')
    const suffix = names.length > 2 ? ` and ${names.length - 2} more are typing` : `${names.length === 1 ? ' is' : ' are'} typing`
    status.textContent = `${visibleNames}${suffix}`
  }

  _handleNewMessageNode(node) {
    if (!(node instanceof Element)) return
    const candidate = node.matches('[data-message-username]') ? node : node.querySelector('[data-message-username]')
    if (!candidate) return
    const key = candidate.dataset.messageUsername
    if (!key) return
    this._removeTypingIndicator(key)
  }

  _styleAllMessages() {
    if (!this.hasContainerTarget) return
    const messages = this.containerTarget.querySelectorAll('.message-bubble')
    messages.forEach(msg => this._styleMessage(msg))
  }

  _styleMessage(node) {
    if (!this._currentUsername) return

    // Find the message bubble element
    const bubble = node.matches?.('.message-bubble') ? node : node.querySelector?.('.message-bubble')
    if (!bubble) return

    const messageUsername = bubble.dataset.messageUsername?.toLowerCase()
    const isOwn = messageUsername === this._currentUsername
    const isGrouped = bubble.dataset.messageGrouped === 'true'

    if (isOwn) {
      // Own message: align right
      bubble.classList.add('msg-row-self')

      // Hide avatar and spacer
      const avatar = bubble.querySelector('.msg-avatar')
      if (avatar) avatar.classList.add('hidden')
      const avatarSpacer = bubble.querySelector('.msg-avatar-spacer')
      if (avatarSpacer) avatarSpacer.classList.add('hidden')

      // Hide name header
      const header = bubble.querySelector('.msg-header')
      if (header) header.classList.add('hidden')

      // Right-align the body content
      const body = bubble.querySelector('.msg-body')
      if (body) body.classList.add('msg-body-self')

      // Style the bubble
      const msgBubble = bubble.querySelector('.msg-bubble')
      if (msgBubble) {
        msgBubble.classList.add('msg-bubble-self')
        msgBubble.style.removeProperty('border-radius')
      }

      const attachments = bubble.querySelector('.mt-2')
      if (attachments) {
        const filesContainer = attachments.querySelector('.flex-wrap')
        if (filesContainer) filesContainer.classList.add('justify-end')
      }
    }
  }

  // Draft saving methods
  _draftKey() {
    if (!this._typingChannelId) return null
    return `homechat_draft_${this._typingChannelId}`
  }

  _saveDraft() {
    const key = this._draftKey()
    if (!key || !this.hasTextareaTarget) return

    const content = this.textareaTarget.value.trim()
    try {
      if (content) {
        localStorage.setItem(key, content)
      } else {
        localStorage.removeItem(key)
      }
    } catch (e) {
      // localStorage may be unavailable or full
    }
  }

  _restoreDraft() {
    const key = this._draftKey()
    if (!key || !this.hasTextareaTarget) return

    try {
      const draft = localStorage.getItem(key)
      if (draft && !this.textareaTarget.value) {
        this.textareaTarget.value = draft
      }
    } catch (e) {
      // localStorage may be unavailable
    }
  }

  _clearDraft() {
    const key = this._draftKey()
    if (!key) return

    try {
      localStorage.removeItem(key)
    } catch (e) {
      // localStorage may be unavailable
    }
  }

  debouncedSaveDraft = (() => {
    return () => {
      if (this._draftSaveTimer) {
        clearTimeout(this._draftSaveTimer)
      }
      this._draftSaveTimer = setTimeout(() => this._saveDraft(), 1000)
    }
  })()

  // Offline handling methods
  _handleOnline() {
    this._isOnline = true
    this._updateOfflineIndicator()
    this._syncQueuedMessages()
  }

  _handleOffline() {
    this._isOnline = false
    this._updateOfflineIndicator()
  }

  _updateOfflineIndicator() {
    if (this.hasOfflineIndicatorTarget) {
      this.offlineIndicatorTarget.classList.toggle('hidden', this._isOnline)
    }
  }

  // Queue a message for later sending when offline
  _queueMessage(channelId, content) {
    try {
      const queue = JSON.parse(localStorage.getItem(MESSAGE_QUEUE_KEY) || '[]')
      queue.push({
        channelId,
        content,
        timestamp: Date.now(),
        id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
      })
      localStorage.setItem(MESSAGE_QUEUE_KEY, JSON.stringify(queue))

      // Register for background sync if available
      if ('serviceWorker' in navigator && 'SyncManager' in window) {
        navigator.serviceWorker.ready.then(reg => {
          reg.sync.register('sync-messages').catch(() => {})
        })
      }

      return true
    } catch (e) {
      console.error('Failed to queue message:', e)
      return false
    }
  }

  // Get queued messages for the current channel
  _getQueuedMessages(channelId) {
    try {
      const queue = JSON.parse(localStorage.getItem(MESSAGE_QUEUE_KEY) || '[]')
      return channelId ? queue.filter(m => m.channelId === channelId) : queue
    } catch (e) {
      return []
    }
  }

  // Sync all queued messages
  async _syncQueuedMessages() {
    if (!this._isOnline) return

    try {
      const queue = JSON.parse(localStorage.getItem(MESSAGE_QUEUE_KEY) || '[]')
      if (queue.length === 0) return

      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const successIds = []

      for (const msg of queue) {
        try {
          const response = await fetch(this._withBasePath(`/channels/${msg.channelId}/messages`), {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': csrfToken,
              'Accept': 'text/vnd.turbo-stream.html'
            },
            body: JSON.stringify({ message: { content: msg.content } })
          })

          if (response.ok) {
            successIds.push(msg.id)
          }
        } catch (e) {
          console.error('Failed to sync message:', e)
        }
      }

      // Remove successfully sent messages from queue
      if (successIds.length > 0) {
        const remaining = queue.filter(m => !successIds.includes(m.id))
        localStorage.setItem(MESSAGE_QUEUE_KEY, JSON.stringify(remaining))

        // Notify user
        if (remaining.length === 0) {
          this._showSyncNotification(`${successIds.length} message(s) sent`)
        } else {
          this._showSyncNotification(`${successIds.length} sent, ${remaining.length} pending`)
        }
      }
    } catch (e) {
      console.error('Failed to sync messages:', e)
    }
  }

  _withBasePath(path) {
    if (!path?.startsWith('/')) return path

    const basePath = document.querySelector('meta[name="homechat-base-path"]')?.content || ''
    return `${basePath}${path}`
  }

  // Show a brief notification about sync status
  _showSyncNotification(message) {
    const notification = document.createElement('div')
    notification.className = 'fixed bottom-4 left-1/2 -translate-x-1/2 bg-green-600 text-white px-4 py-2 rounded-full text-sm font-medium shadow-lg z-50 animate-pulse'
    notification.setAttribute('role', 'status')
    notification.setAttribute('aria-live', 'polite')
    notification.textContent = message
    document.body.appendChild(notification)
    setTimeout(() => notification.remove(), 3000)
  }

  // Intercept form submission when offline
  submitOffline(event) {
    if (this._isOnline) return // Let normal submission proceed

    event.preventDefault()
    event.stopPropagation()
    if (event.stopImmediatePropagation) event.stopImmediatePropagation()

    if (this._e2eeRequiredChannel()) {
      this._showSyncNotification('Offline queue is disabled for encrypted channels')
      return
    }

    const channelId = this.element?.dataset.channelId || this.channelIdValue
    const content = this.hasTextareaTarget ? this.textareaTarget.value.trim() : ''

    if (!content || !channelId) return

    if (this._queueMessage(channelId, content)) {
      // Show pending message in UI
      this._showPendingMessage(content)

      // Clear textarea
      if (this.hasTextareaTarget) {
        this.textareaTarget.value = ''
        this.autoResize()
      }
      this._clearDraft()
    }
  }

  // Show a pending message bubble in the chat
  _showPendingMessage(content) {
    if (!this.hasContainerTarget) return

    const username = this._currentUsername || 'you'
    const pendingHtml = `
      <div class="message-bubble group msg-row msg-row-start msg-row-self opacity-75" data-pending="true" data-message-username="${this._escapeHtml(username)}">
        <div class="msg-body msg-body-self">
          <div class="msg-bubble msg-bubble-self">
            <div class="message-body">${this._escapeHtml(content)}</div>
          </div>
          <div class="mt-1 flex items-center gap-1 text-[10px] text-stone-400">
            <span class="inline-flex items-center gap-1">
              <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
              </svg>
              Queued
            </span>
          </div>
        </div>
      </div>
    `

    const container = this._typingContainer(true) || this.containerTarget
    container.insertAdjacentHTML('beforeend', pendingHtml)
    this._scrollToBottom(true)
  }

  // Escape HTML for safe rendering
  _escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  _e2eeRequiredChannel() {
    const type = this.hasChannelTypeValue ? this.channelTypeValue : this.element?.dataset?.channelType
    return type === 'private' || type === 'dm'
  }
}
