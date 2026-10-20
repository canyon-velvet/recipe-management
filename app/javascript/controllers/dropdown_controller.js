import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // button (optional): the toggle, which then tells screen readers whether the menu is open (aria-expanded)
  static targets = ["menu", "button"]

  // The click carries on to the window, so any other open dropdown closes (its #close sees a click outside it)
  toggle() {
    this.menuTarget.classList.toggle("hidden")
    this.#syncButton()
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }

  hide() {
    this.menuTarget.classList.add("hidden")
    this.#syncButton()
  }

  // A button inside the menu that closes it: focus goes back to the toggle rather than being lost with the menu
  hideAndFocusButton() {
    this.hide()
    this.buttonTarget.focus()
  }

  #syncButton() {
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", !this.menuTarget.classList.contains("hidden"))
    }
  }
}
