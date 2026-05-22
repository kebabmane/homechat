import { Controller } from "@hotwired/stimulus"

// Popover showing channel members when the header count is clicked.
export default class extends Controller {
  static targets = ["panel", "trigger"]
  static values = {
    url: String
  }

  connect() {
    this.boundHandleOutside = this.handleOutside.bind(this)
    this.boundHandleEscape = this.handleEscape.bind(this)
    this._opener = null
  }

  disconnect() {
    this.hide()
  }

  toggle(event) {
    event.preventDefault()
    if (!this.hasPanelTarget) return
    this._opener = event.currentTarget
    const hidden = this.panelTarget.classList.contains("hidden")
    hidden ? this.show() : this.hide()
  }

  show() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.remove("hidden")
    this.panelTarget.setAttribute('aria-hidden', 'false')
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute('aria-expanded', 'true')
    this.loadMembers()
    document.addEventListener("click", this.boundHandleOutside, true)
    document.addEventListener("keydown", this.boundHandleEscape)

    // Focus the panel for keyboard accessibility
    this.panelTarget.setAttribute('tabindex', '-1')
    requestAnimationFrame(() => this.panelTarget.focus())
  }

  hide() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.add("hidden")
    this.panelTarget.setAttribute('aria-hidden', 'true')
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute('aria-expanded', 'false')
    document.removeEventListener("click", this.boundHandleOutside, true)
    document.removeEventListener("keydown", this.boundHandleEscape)

    if (this._opener && typeof this._opener.focus === "function") {
      this._opener.focus()
    }
  }

  handleOutside(event) {
    if (this.element.contains(event.target)) return
    this.hide()
  }

  handleEscape(event) {
    if (event.key === 'Escape') {
      this.hide()
    }
  }

  loadMembers() {
    if (!this.urlValue || !this.hasPanelTarget) return
    this.panelTarget.innerHTML = '<div class="px-4 py-3 text-sm text-gray-500" aria-live="polite">Loading…</div>'
    fetch(this.urlValue, { headers: { Accept: "text/html" } })
      .then((response) => response.text())
      .then((html) => {
        this.panelTarget.innerHTML = html
      })
      .catch(() => {
        this.panelTarget.innerHTML = '<div class="px-4 py-3 text-sm text-red-600" role="alert">Unable to load members.</div>'
      })
  }
}
