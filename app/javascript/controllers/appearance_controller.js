import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The account menu's Light / Dark / Auto switch: turns the page at once, before the form saves the choice. The
// page's colours follow <html data-theme> (theme.css), and the phone's status bar the theme-color tag shown (see
// ApplicationHelper#theme_color_media). The checked choice is always the page's, also on a page from Turbo's cache.
export default class extends Controller {
  static targets = ["option"]

  connect() {
    this.#check(document.documentElement.dataset.theme)
  }

  pick({ currentTarget: { value } }) {
    document.documentElement.dataset.theme = value
    document.body.dataset.appearance = value // for the next page (application.js)
    document.querySelectorAll("meta[name=theme-color]").forEach(meta => {
      const scheme = meta.dataset.scheme
      meta.media = value === "auto" ? `(prefers-color-scheme: ${scheme})` : (value === scheme ? "all" : "not all")
    })
    this.#check(value)
    Turbo.cache.clear() // so Back doesn't bring back a page in the colours chosen before
  }

  // Turbo disables the button while the choice is saved, which takes the keyboard's focus off it: it goes back
  refocus({ detail: { formSubmission: { submitter } } }) {
    submitter?.focus()
  }

  #check(value) {
    this.optionTargets.forEach(option => option.setAttribute("aria-checked", option.value === value))
  }
}
