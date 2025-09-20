import { Controller } from "@hotwired/stimulus"

// Reveals a sticky action bar when the form becomes dirty.
export default class extends Controller {
  static targets = ["bar"]

  connect() {
    this.dirty = false
    this._handleInput = this.handleInput.bind(this)
    this._handleSubmitEnd = this.handleSubmitEnd.bind(this)
    this.element.addEventListener("input", this._handleInput, true)
    this.element.addEventListener("change", this._handleInput, true)
    this.element.addEventListener("turbo:submit-end", this._handleSubmitEnd)
    this.markClean()
  }

  disconnect() {
    this.element.removeEventListener("input", this._handleInput, true)
    this.element.removeEventListener("change", this._handleInput, true)
    this.element.removeEventListener("turbo:submit-end", this._handleSubmitEnd)
  }

  handleInput() {
    if (this.dirty) return
    this.dirty = true
    this.showBar()
  }

  handleSubmitEnd(event) {
    if (event.detail?.success) {
      this.markClean()
    }
  }

  reset(event) {
    event.preventDefault()
    this.element.reset()
    this.markClean()
  }

  showBar() {
    if (!this.hasBarTarget) return
    this.barTarget.classList.remove("hidden")
  }

  markClean() {
    this.dirty = false
    if (this.hasBarTarget) {
      this.barTarget.classList.add("hidden")
    }
  }
}
