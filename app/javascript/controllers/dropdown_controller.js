import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  // The click carries on to the window, so any other open dropdown closes (its #close sees a click outside it)
  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }

  hide() {
    this.menuTarget.classList.add("hidden")
  }
}
