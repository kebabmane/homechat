import { Controller } from "@hotwired/stimulus"

const COLLAPSE_KEY = "sidebarCollapsed"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this.collapsed = this.readPersistedCollapse()

    this._onKeydown = (event) => {
      if (event.key === "Escape") this.close()
    }
    this._onResize = () => {
      this.applyCollapse()
    }
    window.addEventListener("keydown", this._onKeydown)
    window.addEventListener("resize", this._onResize)
    this.applyCollapse()
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
    window.removeEventListener("resize", this._onResize)
  }

  open(event) {
    event?.preventDefault()
    if (this.isDesktop()) {
      this.setCollapsed(false)
    } else {
      this.openMobile()
    }
  }

  close(event) {
    event?.preventDefault()
    if (this.isDesktop()) {
      this.setCollapsed(true)
    } else {
      this.closeMobile()
    }
  }

  togglePinned(event) {
    event?.preventDefault()
    if (this.isDesktop()) {
      this.setCollapsed(!this.collapsed)
    } else {
      this.closeMobile()
    }
  }

  openPinned(event) {
    event?.preventDefault()
    this.setCollapsed(false)
  }

  setCollapsed(value) {
    this.collapsed = Boolean(value)
    this.persistCollapse()
    this.applyCollapse()
  }

  applyCollapse() {
    const desktop = this.isDesktop()
    const shouldCollapse = desktop && this.collapsed

    if (this.hasPanelTarget) {
      if (desktop) {
        // On desktop, sidebar should always be visible unless collapsed
        if (shouldCollapse) {
          // Hide the sidebar completely when collapsed
          this.panelTarget.classList.add("hidden")
        } else {
          // Show the sidebar when not collapsed
          this.panelTarget.classList.remove("hidden")
          this.panelTarget.classList.remove("-translate-x-full")
          this.panelTarget.classList.add("translate-x-0")
        }
      } else {
        // On mobile, never use hidden class, use transform instead
        this.panelTarget.classList.remove("hidden")
      }
    }

    if (!desktop) {
      this.collapsed = false
      this.closeMobile()
    }
  }

  openMobile() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.remove("-translate-x-full")
      this.panelTarget.classList.add("translate-x-0")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
    }
  }

  closeMobile() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("-translate-x-full")
      this.panelTarget.classList.remove("translate-x-0")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("hidden")
    }
  }

  isDesktop() {
    return window.matchMedia("(min-width: 768px)").matches
  }

  readPersistedCollapse() {
    try {
      return window.localStorage.getItem(COLLAPSE_KEY) === "true"
    } catch (_) {
      return false
    }
  }

  persistCollapse() {
    try {
      window.localStorage.setItem(COLLAPSE_KEY, this.collapsed ? "true" : "false")
    } catch (_) {}
  }
}
