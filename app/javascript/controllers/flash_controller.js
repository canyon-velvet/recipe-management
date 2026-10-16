import { Controller } from "@hotwired/stimulus"

// A notice under the navbar. One that something worked fades away by itself, unless the pointer or the keyboard is
// on it (being read, or about to be closed); one about a problem stays until its × is clicked, so it isn't missed.
export default class extends Controller {
  static values = { autoHide: Boolean }

  connect() {
    if (!this.autoHideValue) return

    this.timeout = setTimeout(() => this.dismiss(), 5000)
    this.keep = () => clearTimeout(this.timeout)
    this.element.addEventListener("mouseenter", this.keep)
    this.element.addEventListener("focusin", this.keep)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("flash--leaving") // fades out (flash.css), then goes
    setTimeout(() => this.element.remove(), 300)
  }
}
