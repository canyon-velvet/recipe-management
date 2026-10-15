import { Controller } from "@hotwired/stimulus"

// Copies the source field's text, e.g. an invite link, and says so on the button. Where the browser won't copy (it
// only does on https or localhost), the text is selected instead, to copy by hand.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copiedText: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.buttonTarget.textContent = this.copiedTextValue
    } catch {
      this.sourceTarget.select()
    }
  }
}
