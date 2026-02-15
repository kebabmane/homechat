import { Controller } from "@hotwired/stimulus"

const COLLAPSE_KEY = "sidebarCollapsed"
const SWIPE_THRESHOLD = 50 // Minimum distance to trigger swipe
const EDGE_ZONE = 30 // Pixels from left edge to start swipe-to-open

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

    // Touch gesture state
    this.touchStartX = 0
    this.touchStartY = 0
    this.touchCurrentX = 0
    this.isSwiping = false
    this.swipeStartedFromEdge = false

    // Bind touch handlers
    this._onTouchStart = this.handleTouchStart.bind(this)
    this._onTouchMove = this.handleTouchMove.bind(this)
    this._onTouchEnd = this.handleTouchEnd.bind(this)

    window.addEventListener("keydown", this._onKeydown)
    window.addEventListener("resize", this._onResize)

    // Add touch listeners for swipe gestures (mobile only)
    document.addEventListener("touchstart", this._onTouchStart, { passive: true })
    document.addEventListener("touchmove", this._onTouchMove, { passive: false })
    document.addEventListener("touchend", this._onTouchEnd, { passive: true })

    this.applyCollapse()
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
    window.removeEventListener("resize", this._onResize)
    document.removeEventListener("touchstart", this._onTouchStart)
    document.removeEventListener("touchmove", this._onTouchMove)
    document.removeEventListener("touchend", this._onTouchEnd)
  }

  // Touch gesture handlers
  handleTouchStart(event) {
    if (this.isDesktop()) return

    const touch = event.touches[0]
    this.touchStartX = touch.clientX
    this.touchStartY = touch.clientY
    this.touchCurrentX = touch.clientX
    this.isSwiping = false

    // Check if swipe started from left edge (for opening)
    this.swipeStartedFromEdge = touch.clientX < EDGE_ZONE && !this.isMobileOpen()
  }

  handleTouchMove(event) {
    if (this.isDesktop()) return

    const touch = event.touches[0]
    const deltaX = touch.clientX - this.touchStartX
    const deltaY = touch.clientY - this.touchStartY

    // Only track horizontal swipes (ignore vertical scrolling)
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 10) {
      this.isSwiping = true
      this.touchCurrentX = touch.clientX

      // Prevent scrolling during horizontal swipe
      if (this.swipeStartedFromEdge || this.isMobileOpen()) {
        event.preventDefault()
      }
    }
  }

  handleTouchEnd(event) {
    if (this.isDesktop() || !this.isSwiping) return

    const deltaX = this.touchCurrentX - this.touchStartX

    // Swipe right from edge to open
    if (this.swipeStartedFromEdge && deltaX > SWIPE_THRESHOLD) {
      this.openMobile()
    }
    // Swipe left to close (when sidebar is open)
    else if (this.isMobileOpen() && deltaX < -SWIPE_THRESHOLD) {
      this.closeMobile()
    }

    // Reset state
    this.isSwiping = false
    this.swipeStartedFromEdge = false
  }

  isMobileOpen() {
    return this.hasPanelTarget &&
           this.panelTarget.classList.contains("translate-x-0") &&
           !this.panelTarget.classList.contains("-translate-x-full")
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
    // Lock body scroll when sidebar is open on mobile
    document.body.classList.add("overflow-hidden")
  }

  closeMobile() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("-translate-x-full")
      this.panelTarget.classList.remove("translate-x-0")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("hidden")
    }
    // Restore body scroll when sidebar closes
    document.body.classList.remove("overflow-hidden")
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
