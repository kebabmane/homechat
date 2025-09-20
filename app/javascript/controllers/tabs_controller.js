import { Controller } from "@hotwired/stimulus"

// Simple tabs controller toggles active tab and panel visibility
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    active: String
  }

  connect() {
    if (!this.hasActiveValue && this.hasTabTarget) {
      const first = this.tabTargets[0]?.dataset.tabsId
      if (first) this.activeValue = first
    }
    this.showActive()
  }

  select(event) {
    event.preventDefault()
    const tab = event.currentTarget
    const id = tab?.dataset.tabsId
    if (!id) return
    this.activeValue = id
    this.showActive()
    tab.focus()
  }

  showActive() {
    if (!this.hasTabTarget) return
    let current = this.activeValue
    if (!current) {
      current = this.tabTargets[0]?.dataset.tabsId
      this.activeValue = current
    }

    this.tabTargets.forEach((tab) => {
      const isActive = tab.dataset.tabsId === current
      tab.classList.toggle("is-active", isActive)
      tab.setAttribute("aria-selected", isActive)
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
    })

    this.panelTargets.forEach((panel) => {
      const isActive = panel.dataset.tabsId === current
      panel.classList.toggle("hidden", !isActive)
      panel.setAttribute("aria-hidden", (!isActive).toString())
    })
  }
}
