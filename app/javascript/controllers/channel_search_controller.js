import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item"]

  filter() {
    const q = this.inputTarget.value.trim().toLowerCase()
    this.itemTargets.forEach(el => {
      const name = (el.dataset.name || '').toLowerCase()
      el.classList.toggle('hidden', q && !name.includes(q))
    })
  }

  connect() {
    this.filter()
  }
}

