import { Controller } from "@hotwired/stimulus"
import { subscribeToTyping, broadcastTyping, unsubscribeTyping } from "channels/typing_channel"

// Manages channel message area interactions: scroll, header shadow, textarea autosize.
export default class extends Controller {
  static targets = ["container", "header", "textarea", "scrollButton", "typingIndicator"]
  static values = {
    autoscroll: { type: Boolean, default: true },
    autofocus: { type: Boolean, default: false },
    currentUser: String
  }

  connect() {
    this._typingTimers = new Map()
    this._typingContainerEl = this.hasTypingIndicatorTarget ? this.typingIndicatorTarget : null
    this._draftSaveTimer = null

    // Get current username for message styling
    const currentUser = this.hasCurrentUserValue ? this.currentUserValue : (document.querySelector('[data-current-username]')?.dataset.currentUsername || null)
    this._currentUsername = currentUser ? currentUser.toLowerCase() : null

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
    unsubscribeTyping()
    this._typingChannelId = null
    this._currentUsername = null
    this._typingContainerEl = null
  }

  // Called on turbo:submit-end from the form
  afterSubmit() {
    if (this.hasTextareaTarget) {
      this.textareaTarget.value = ""
      this.autoResize()
      if (this.autofocusValue) {
        this.textareaTarget.focus()
      }
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

    // Typing indicator dots
    const dotsContainer = document.createElement('div')
    dotsContainer.className = 'inline-flex items-center gap-1 rounded-full bg-gray-100 px-3 py-1 text-xs text-gray-600 animate-pulse'

    const srSpan = document.createElement('span')
    srSpan.className = 'sr-only'
    srSpan.textContent = 'Typing'
    dotsContainer.appendChild(srSpan)

    for (let i = 0; i < 3; i++) {
      const dot = document.createElement('span')
      dot.className = 'w-2 h-2 rounded-full bg-gray-400'
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

    if (isOwn) {
      // Own message: align right, blue bubble, hide avatar/name
      bubble.classList.add('flex-row-reverse')

      const avatar = bubble.querySelector('.message-avatar')
      if (avatar) avatar.classList.add('hidden')

      const header = bubble.querySelector('.message-header')
      if (header) header.classList.add('hidden')

      const content = bubble.querySelector('.message-content')
      if (content) {
        content.classList.remove('items-start')
        content.classList.add('items-end')
      }

      const text = bubble.querySelector('.message-text')
      if (text) {
        text.classList.remove('bg-gray-100', 'text-gray-900', 'rounded-bl-md')
        text.classList.add('bg-blue-500', 'text-white', 'rounded-br-md')
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
}
