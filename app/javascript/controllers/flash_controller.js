import { Controller } from "@hotwired/stimulus"

// A notice under the navbar. One that something worked fades away by itself; one about a problem stays until its ×
// is clicked, so it isn't missed.
export default class extends Controller {
  static values = { autoHide: Boolean }

  connect() {
    if (this.autoHideValue) this.timeout = setTimeout(() => this.dismiss(), 5000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("flash--leaving") // fades out (flash.css), then goes
    setTimeout(() => this.element.remove(), 300)
  }
}
