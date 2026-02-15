import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcuts
// Cmd+K is handled by command_palette_controller
export default class extends Controller {
  connect() {
    this._onKeydown = (e) => {
      // "/" to focus message composer (when not in input)
      if (e.key === "/" && !this.isInputFocused()) {
        const composer = document.querySelector('[data-message-list-target="textarea"]')
        if (composer) {
          e.preventDefault()
          composer.focus()
        }
      }

      // Escape to blur current input
      if (e.key === "Escape" && this.isInputFocused()) {
        document.activeElement.blur()
      }
    }
    window.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
  }

  isInputFocused() {
    const tag = document.activeElement?.tagName
    return tag === "INPUT" || tag === "TEXTAREA" || document.activeElement?.isContentEditable
  }
}

