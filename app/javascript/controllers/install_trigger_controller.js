import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  trigger() {
    window.dispatchEvent(new CustomEvent('pwa-show-install'))
  }
}

