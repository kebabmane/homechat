import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["enter"]

  connect() {
    const val = localStorage.getItem("enterToSend")
    const enabled = val === null ? true : val !== 'false'
    if (this.hasEnterTarget) this.enterTarget.checked = enabled
  }

  save() {
    if (this.hasEnterTarget) {
      localStorage.setItem("enterToSend", this.enterTarget.checked ? 'true' : 'false')
    }
  }
}

