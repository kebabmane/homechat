import { Controller } from "@hotwired/stimulus"

// Simple image lightbox: clicking an image opens it full screen; click backdrop to close
export default class extends Controller {
  open(event) {
    const src = event.currentTarget.getAttribute('src')
    if (!src) return
    this.overlay = document.createElement('div')
    this.overlay.className = 'fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4'
    this.overlay.addEventListener('click', () => this.close())
    const img = document.createElement('img')
    img.src = src
    img.className = 'max-h-full max-w-full rounded shadow-lg'
    img.addEventListener('click', (e) => e.stopPropagation())
    this.overlay.appendChild(img)
    document.body.appendChild(this.overlay)
  }

  close() {
    if (this.overlay) {
      this.overlay.remove()
      this.overlay = null
    }
  }
}

