import { Controller } from "@hotwired/stimulus"

// Popover showing channel members when the header count is clicked.
export default class extends Controller {
  static targets = ["panel"]
  static values = {
    url: String
  }

  connect() {
    this.boundHandleOutside = this.handleOutside.bind(this)
  }

  disconnect() {
    this.hide()
  }

  toggle(event) {
    event.preventDefault()
    if (!this.hasPanelTarget) return
    const hidden = this.panelTarget.classList.contains("hidden")
    hidden ? this.show() : this.hide()
  }

  show() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.remove("hidden")
    this.loadMembers()
    document.addEventListener("click", this.boundHandleOutside, true)
  }

  hide() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.add("hidden")
    document.removeEventListener("click", this.boundHandleOutside, true)
  }

  handleOutside(event) {
    if (this.element.contains(event.target)) return
    this.hide()
  }

  loadMembers() {
    if (!this.urlValue || !this.hasPanelTarget) return
    this.panelTarget.innerHTML = '<div class="px-4 py-3 text-sm text-gray-500">Loading…</div>'
    fetch(this.urlValue, { headers: { Accept: "text/html" } })
      .then((response) => response.text())
      .then((html) => {
        this.panelTarget.innerHTML = html
      })
      .catch(() => {
        this.panelTarget.innerHTML = '<div class="px-4 py-3 text-sm text-red-600">Unable to load members.</div>'
      })
  }
}
