import { Controller } from "@hotwired/stimulus"

// Navigates to the selected admin section on small screens.
export default class extends Controller {
  change(event) {
    const url = event.target.value
    if (url && url !== window.location.pathname) {
      window.location.assign(url)
    }
  }
}
