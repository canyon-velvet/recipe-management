import { Controller } from "@hotwired/stimulus"

// Marks its element .is-scrolled while the page is scrolled down, e.g. so the navbar shows an edge once
// the page passes under it. Updated on the window's scroll events (data-action), and on connect for a restored page.
export default class extends Controller {
  connect() {
    this.update()
  }

  update() {
    this.element.classList.toggle("is-scrolled", window.scrollY > 0)
  }
}
