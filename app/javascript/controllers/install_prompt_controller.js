import { Controller } from "@hotwired/stimulus"

// Shows an install prompt toast when PWA is installable.
export default class extends Controller {
  static targets = ["toast"]

  connect() {
    if (!window || !('serviceWorker' in navigator)) return
    if (localStorage.getItem('pwaInstallDismissed') === 'true') return

    this._handler = (e) => {
      // Prevent the native mini-infobar on mobile
      e.preventDefault()
      this.deferredPrompt = e
      this.show()
    }
    window.addEventListener('beforeinstallprompt', this._handler)

    // Allow other parts of the app to request showing the toast
    this._requestHandler = () => {
      if (this.deferredPrompt) {
        this.show()
      } else {
        // Remember the request so we show when available
        this._requested = true
      }
    }
    window.addEventListener('pwa-show-install', this._requestHandler)
  }

  disconnect() {
    window.removeEventListener('beforeinstallprompt', this._handler)
    window.removeEventListener('pwa-show-install', this._requestHandler)
  }

  async install() {
    if (!this.deferredPrompt) return this.dismiss()
    this.toastTarget.classList.add('pointer-events-none', 'opacity-50')
    const { outcome } = await this.deferredPrompt.prompt()
    this.deferredPrompt = null
    this.dismiss()
  }

  dismiss() {
    localStorage.setItem('pwaInstallDismissed', 'true')
    this.hide()
  }

  show() { this.toastTarget.classList.remove('hidden') }
  hide() { this.toastTarget.classList.add('hidden') }

  // Optional: called by triggers (e.g., menu item)
  request() {
    window.dispatchEvent(new CustomEvent('pwa-show-install'))
  }
}
