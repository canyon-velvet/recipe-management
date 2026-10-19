import { Controller } from "@hotwired/stimulus"

// Opens the phone's share sheet (Messages, WeChat…) for a link. Shown only where the browser has one; elsewhere the
// link is copied instead.
export default class extends Controller {
  static values = { url: String, title: String }

  connect() {
    this.element.hidden = !navigator.share
  }

  share() {
    navigator.share({ title: this.titleValue, url: this.urlValue }).catch(() => {}) // closing the sheet rejects
  }
}
