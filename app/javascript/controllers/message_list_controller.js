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
      if (this.autofocusValue) {
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

  // Called on turbo:submit-end from the form
  afterSubmit(event) {
    // Check if submission was successful (Turbo provides detail.success)
    const success = event?.detail?.success !== false

    if (this.hasTextareaTarget) {
      this.textareaTarget.value = ""
      this.autoResize()
      this.textareaTarget.focus()
    }

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

  // Show brief visual feedback after sending a message
  _showSendConfirmation() {
    if (!this.hasSendButtonTarget) return

    const btn = this.sendButtonTarget
    const originalText = btn.textContent
    const originalClasses = btn.className

    // Briefly show checkmark with success styling
    btn.innerHTML = `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
      </svg>
    `
    btn.classList.remove('bg-blue-600', 'hover:bg-blue-700')
    btn.classList.add('bg-green-500', 'scale-105')

    // Add subtle pulse animation
    btn.style.transition = 'transform 150ms ease-out, background-color 150ms ease-out'

    // Restore original state after brief delay
    setTimeout(() => {
      btn.textContent = originalText
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
      return
    }
    this._scrollToBottom(Boolean(arg))
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
      // Own message: align right, blue bubble, hide avatar/name
      bubble.classList.add('flex-row-reverse')

      const avatar = bubble.querySelector('.message-avatar')
      if (avatar) avatar.classList.add('hidden')

      // Also hide the spacer for grouped messages
      const avatarSpacer = bubble.querySelector('.message-avatar-spacer')
      if (avatarSpacer) avatarSpacer.classList.add('hidden')

      const header = bubble.querySelector('.message-header')
      if (header) header.classList.add('hidden')

      const content = bubble.querySelector('.message-content')
      if (content) {
        content.classList.remove('items-start')
        content.classList.add('items-end')
      }

      const text = bubble.querySelector('.message-text')
      if (text) {
        text.classList.remove('bg-gray-100', 'text-gray-900', 'rounded-bl-md', 'rounded-l-md')
        text.classList.add('bg-blue-500', 'text-white')
        // Apply appropriate corner rounding for own messages
        text.classList.add(isGrouped ? 'rounded-r-md' : 'rounded-br-md')
        // Style links in own messages
        const body = text.querySelector('.message-body')
        if (body) {
          body.querySelectorAll('a').forEach(a => {
            a.classList.add('text-blue-100', 'underline')
          })
        }
      }

      const time = bubble.querySelector('.message-time')
      if (time) {
        time.classList.remove('ml-1')
        time.classList.add('mr-1')
      }

      const attachments = bubble.querySelector('.message-attachments')
      if (attachments) {
        attachments.classList.remove('pl-1')
        attachments.classList.add('pr-1')
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
          const response = await fetch(`/channels/${msg.channelId}/messages`, {
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

  // Show a brief notification about sync status
  _showSyncNotification(message) {
    const notification = document.createElement('div')
    notification.className = 'fixed bottom-4 left-1/2 -translate-x-1/2 bg-green-600 text-white px-4 py-2 rounded-full text-sm font-medium shadow-lg z-50 animate-pulse'
    notification.textContent = message
    document.body.appendChild(notification)
    setTimeout(() => notification.remove(), 3000)
  }

  // Intercept form submission when offline
  submitOffline(event) {
    if (this._isOnline) return // Let normal submission proceed

    if (this._e2eeRequiredChannel()) {
      this._showSyncNotification('Offline queue is disabled for encrypted channels')
      return
    }

    event.preventDefault()
    event.stopPropagation()

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

    const pendingHtml = `
      <div class="group message-bubble flex items-end gap-2 px-2 py-1 flex-row-reverse opacity-70" data-pending="true">
        <div class="message-content flex flex-col items-end max-w-[85%] sm:max-w-[75%] min-w-0">
          <div class="message-text bg-blue-400 text-white rounded-2xl rounded-br-md px-4 py-2.5 shadow-sm text-[15px] leading-relaxed break-words">
            <div class="message-body">${this._escapeHtml(content)}</div>
          </div>
          <div class="message-time flex items-center gap-1 mt-0.5 mr-1">
            <span class="text-[10px] text-gray-400 flex items-center gap-1">
              <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
              </svg>
              Sending...
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
