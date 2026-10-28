import { Controller } from "@hotwired/stimulus"

// The New tag pop-up's emoji: one tapped from the grid, typed from the keyboard, or none. The tapped one shows as
// pressed; sync also runs as the pop-up opens, as its fields are emptied for the next tag.
export default class extends Controller {
  static targets = ["input", "choice"]

  pick({ params: { emoji } }) {
    this.inputTarget.value = emoji
    this.sync()
  }

  clear() {
    this.inputTarget.value = ""
    this.sync()
  }

  sync() {
    const emoji = this.inputTarget.value.trim()
    this.choiceTargets.forEach(choice => choice.setAttribute("aria-pressed", choice.textContent.trim() === emoji))
  }
}
