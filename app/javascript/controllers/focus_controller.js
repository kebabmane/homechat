import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Delay to next frame to ensure it's visible
    requestAnimationFrame(() => {
      this.element.focus()
      this.element.select?.()
    })
  }
}

