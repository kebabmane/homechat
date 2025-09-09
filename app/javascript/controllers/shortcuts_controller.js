import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._onKeydown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        if (window.Turbo) window.Turbo.visit('/channels?focus=search')
      }
    }
    window.addEventListener('keydown', this._onKeydown)
  }

  disconnect() {
    window.removeEventListener('keydown', this._onKeydown)
  }
}

