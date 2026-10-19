import { Controller } from "@hotwired/stimulus"

// Opens the phone's share sheet (Messages, WeChat…) for a link, and sends share:shared once it's shared (the share
// pop-up then closes). Shown only where the browser has one; elsewhere the link is copied instead.
export default class extends Controller {
  static values = { url: String, title: String }

  connect() {
    this.element.hidden = !navigator.share
  }

  share() {
    navigator.share({ title: this.titleValue, url: this.urlValue })
      .then(() => this.dispatch("shared"), () => {}) // closing the sheet without sharing rejects
  }
}
