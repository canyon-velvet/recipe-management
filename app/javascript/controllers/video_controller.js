import { Controller } from "@hotwired/stimulus"

// A video that starts when its pop-up opens and stops when the pop-up closes (the login page's tour)
export default class extends Controller {
  static targets = ["video"]

  play() {
    // Rejected when the pop-up is closed again before it starts; its own play button is there either way
    this.videoTarget.play().catch(() => {})
  }

  pause() {
    this.videoTarget.pause()
  }
}
