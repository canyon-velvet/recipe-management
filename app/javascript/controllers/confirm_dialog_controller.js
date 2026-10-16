import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Turbo asks before submitting anything with data-turbo-confirm (a Delete link or button). This answers with the app's
// own pop-up instead of the browser's confirm(): Delete goes ahead; Cancel, Esc or a click outside doesn't.
export default class extends Controller {
  static targets = ["message"]

  connect() {
    Turbo.config.forms.confirm = (message) => this.ask(message)
  }

  ask(message) {
    this.answer(false) // an earlier question still open gets a no, so it never stays pending
    this.messageTarget.textContent = message
    this.element.showModal()
    return new Promise((resolve) => { this.resolve = resolve })
  }

  confirm() {
    this.answer(true)
  }

  cancel() {
    this.answer(false)
  }

  // Esc closes the dialog without an answer: that's a no.
  closed() {
    this.answer(false)
  }

  backdropClose(event) {
    if (event.target === this.element) this.cancel()
  }

  answer(value) {
    const resolve = this.resolve
    this.resolve = null
    if (this.element.open) this.element.close()
    resolve?.(value)
  }
}
