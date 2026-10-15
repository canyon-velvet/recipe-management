import { Controller } from "@hotwired/stimulus"

// Copies the source field's text, e.g. an invite link, and says so on the button.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copiedText: String }

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    this.buttonTarget.textContent = this.copiedTextValue
  }
}
