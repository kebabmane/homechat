import { Controller } from "@hotwired/stimulus"
import { subscribeToTyping, broadcastTyping } from "channels/typing_channel"

// Manages channel message area interactions: scroll, header shadow, textarea autosize.
export default class extends Controller {
  static targets = ["container", "header", "textarea", "scrollButton"]

  connect() {
    // Ensure newest messages are visible
    this.scrollToBottom()

    // Header shadow on scroll
    if (this.hasContainerTarget) {
      this._onScroll = () => {
        this.updateHeaderShadow()
        this.updateScrollButton()
      }
      this.containerTarget.addEventListener("scroll", this._onScroll)
      this.updateHeaderShadow()
      this.updateScrollButton()
    }

    // Autosize composer
    if (this.hasTextareaTarget) {
      this.autoResize()
      // Auto-focus composer on load
      this.textareaTarget.focus()
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
  }

  // Called on turbo:submit-end from the form
  afterSubmit() {
    if (this.hasTextareaTarget) {
      this.textareaTarget.value = ""
      this.autoResize()
      this.textareaTarget.focus()
    }
    this.scrollToBottom()
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

  scrollToBottom() {
    if (!this.hasContainerTarget) return
    const el = this.containerTarget
    el.scrollTop = el.scrollHeight
  }

  updateHeaderShadow() {
    if (!this.hasHeaderTarget || !this.hasContainerTarget) return
    const scrolled = this.containerTarget.scrollTop > 0
    this.headerTarget.classList.toggle("shadow-sm", scrolled)
  }

  updateScrollButton() {
    if (!this.hasContainerTarget) return
    if (!this.hasScrollButtonTarget) return
    const el = this.containerTarget
    const atBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 16
    this.scrollButtonTarget.classList.toggle("hidden", atBottom)
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
}
