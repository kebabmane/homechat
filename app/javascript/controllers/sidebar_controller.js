import { Controller } from "@hotwired/stimulus"

// Controls the mobile slide-in sidebar and backdrop
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this.close()
    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close()
    }
    window.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
  }

  open() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.remove("-translate-x-full")
      this.panelTarget.classList.add("translate-x-0")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
    }
  }

  close() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("-translate-x-full")
      this.panelTarget.classList.remove("translate-x-0")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("hidden")
    }
  }
}

