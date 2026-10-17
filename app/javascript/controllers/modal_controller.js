import { Controller } from "@hotwired/stimulus"

// frame (optional): a Turbo Frame in the dialog, loaded from another page. It's loaded again once the dialog has
// closed, however it was closed (Cancel, ×, Esc, a click outside), so the next open starts afresh.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  open() {
    this.dialogTarget.showModal()
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.dialogTarget.close()
    document.body.classList.remove("overflow-hidden")
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  closed() {
    document.body.classList.remove("overflow-hidden")
    if (this.hasFrameTarget) this.frameTarget.reload()
  }
}
