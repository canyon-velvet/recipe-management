import { Controller } from "@hotwired/stimulus"

// Copies the source field's text, e.g. an invite link, says so on the button, and sends clipboard:copied (the share
// pop-up then closes). Where the browser won't copy (it only does on https or localhost), the text is selected
// instead, to copy by hand.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copiedText: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.buttonTarget.textContent = this.copiedTextValue
      this.dispatch("copied")
    } catch {
      this.sourceTarget.select()
    }
  }
}
