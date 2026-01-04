import { Controller } from "@hotwired/stimulus"

// Simple image lightbox: clicking an image opens it full screen; click backdrop or Escape to close
export default class extends Controller {
  open(event) {
    const src = event.currentTarget.getAttribute('src')
    if (!src) return

    this.overlay = document.createElement('div')
    this.overlay.className = 'fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4'
    this.overlay.setAttribute('role', 'dialog')
    this.overlay.setAttribute('aria-modal', 'true')
    this.overlay.setAttribute('aria-label', 'Image preview')
    this.overlay.addEventListener('click', () => this.close())

    const img = document.createElement('img')
    img.src = src
    img.alt = 'Enlarged image preview'
    img.className = 'max-h-full max-w-full rounded shadow-lg'
    img.addEventListener('click', (e) => e.stopPropagation())

    this.overlay.appendChild(img)
    document.body.appendChild(this.overlay)

    // Add Escape key listener
    this._escapeHandler = (e) => {
      if (e.key === 'Escape') this.close()
    }
    document.addEventListener('keydown', this._escapeHandler)

    // Focus the overlay for keyboard accessibility
    this.overlay.setAttribute('tabindex', '-1')
    this.overlay.focus()
  }

  close() {
    if (this.overlay) {
      this.overlay.remove()
      this.overlay = null
    }
    if (this._escapeHandler) {
      document.removeEventListener('keydown', this._escapeHandler)
      this._escapeHandler = null
    }
  }
}

