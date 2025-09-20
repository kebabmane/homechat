import { Controller } from "@hotwired/stimulus"
import { subscribeToTyping, broadcastTyping } from "channels/typing_channel"

// Manages channel message area interactions: scroll, header shadow, textarea autosize.
export default class extends Controller {
  static targets = ["container", "header", "textarea", "scrollButton"]
  static values = {
    autoscroll: { type: Boolean, default: true },
    autofocus: { type: Boolean, default: false }
  }

  connect() {
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
        if (!this.autoscrollValue) return
        if (mutations.some((mutation) => mutation.addedNodes.length > 0)) {
          this._scrollToBottom(false)
        }
      })
      this._observer.observe(this.containerTarget, { childList: true, subtree: true })
    }

    // Autosize composer
    if (this.hasTextareaTarget) {
      this.autoResize()
      if (this.autofocusValue) {
        this.textareaTarget.focus()
      }
    }

    // Subscribe to typing events for this channel (read from data-channel-id on root)
    const channelId = this.element?.dataset.channelId
    if (channelId) {
      subscribeToTyping(channelId, (data) => this.showTyping(data))
      this._typingChannelId = channelId
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
    this.autoscrollValue = nearBottom
  }

  showTyping({ username }) {
    if (!this.hasHeaderTarget) return
    clearTimeout(this._typingTimer)
    let badge = this.headerTarget.querySelector('[data-typing-badge]')
    if (!badge) {
      badge = document.createElement('span')
      badge.dataset.typingBadge = ""
      badge.className = 'ml-3 text-xs text-gray-500'
      this.headerTarget.appendChild(badge)
    }
    badge.textContent = `${username} is typing…`
    this._typingTimer = setTimeout(() => {
      if (badge) badge.remove()
    }, 1500)
  }

  debouncedBroadcastTyping = (() => {
    let last = 0
    return () => {
      const now = Date.now()
      if (now - last < 800) return
      last = now
      if (this._typingChannelId) {
        const nameEl = document.querySelector('[data-current-username]')
        const name = nameEl?.dataset.currentUsername
        if (name) broadcastTyping(this._typingChannelId, name)
      }
    }
  })()

  _scrollToBottom(force = false) {
    if (!this.hasContainerTarget) return
    if (!force && !this.autoscrollValue) return
    const el = this.containerTarget
    if (!force && !this._isNearBottom()) return
    el.scrollTop = el.scrollHeight
    this.updateScrollButton()
  }

  _isNearBottom(threshold = 96) {
    if (!this.hasContainerTarget) return true
    const el = this.containerTarget
    return el.scrollHeight - el.scrollTop - el.clientHeight < threshold
  }
}
