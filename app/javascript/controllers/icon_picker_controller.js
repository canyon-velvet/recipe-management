import { Controller } from "@hotwired/stimulus"

// The recipe form's icon: the tapped one goes in the hidden field and shows on the tile, pressed in the grid. None
// (an empty icon) shows the placeholder.
export default class extends Controller {
  static targets = ["input", "emoji", "placeholder", "choice"]

  pick({ params: { icon } }) {
    this.inputTarget.value = icon
    this.emojiTarget.textContent = icon
    this.emojiTarget.hidden = !icon
    this.placeholderTarget.hidden = !!icon
    this.choiceTargets.forEach(choice => {
      choice.setAttribute("aria-pressed", choice.dataset.iconPickerIconParam === icon)
    })
  }
}
