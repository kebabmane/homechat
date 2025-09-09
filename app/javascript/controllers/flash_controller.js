import { Controller } from "@hotwired/stimulus"

// Dismissible, auto-hiding flash banner
export default class extends Controller {
  static values = { timeout: { type: Number, default: 4000 } }

  connect() {
    this.element.classList.add("transition", "duration-300", "opacity-100")
    if (this.timeoutValue > 0) {
      this._timer = setTimeout(() => this.close(), this.timeoutValue)
    }
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  close() {
    this.element.classList.add("opacity-0", "pointer-events-none")
    setTimeout(() => this.element.remove(), 300)
  }
}

