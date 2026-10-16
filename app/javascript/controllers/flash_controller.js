import { Controller } from "@hotwired/stimulus"

// A notice at the top of the window. One that something worked fades away by itself, but not while the pointer or
// the keyboard is on it (being read, or about to be closed): then it goes a little after they leave. One about a
// problem stays until its × is clicked, so it isn't missed.
export default class extends Controller {
  static values = { autoHide: Boolean }

  connect() {
    this.hideAfter(5000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  pause() {
    clearTimeout(this.timeout)
  }

  // The pointer or the keyboard left; the other may still be on it.
  resume(event) {
    const stillOn = event.type === "mouseleave" ? ":focus-within" : ":hover"
    if (!this.element.matches(stillOn)) this.hideAfter(2000)
  }

  dismiss() {
    this.element.classList.add("flash--leaving") // fades out (flash.css), then goes
    setTimeout(() => this.element.remove(), 300)
  }

  hideAfter(delay) {
    if (!this.autoHideValue) return

    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.dismiss(), delay)
  }
}
