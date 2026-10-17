import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a field changes (e.g. picking a time zone), with no Save button.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
