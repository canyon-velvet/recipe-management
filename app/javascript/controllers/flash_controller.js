import { Controller } from "@hotwired/stimulus"

// A notice at the top of the page, closed with its ×. Unlike a toast it doesn't go by itself, so it can be read.
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
