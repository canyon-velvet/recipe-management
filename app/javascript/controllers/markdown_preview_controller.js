import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "writeTab", "previewTab"]
  static values = { emptyText: String, url: String }

  connect() {
    this.showWrite()
  }

  showWrite() {
    this.inputTarget.classList.remove("hidden")
    this.previewTarget.classList.add("hidden")
    this.writeTabTarget.classList.add("tab-active")
    this.previewTabTarget.classList.remove("tab-active")
  }

  async showPreview() {
    const text = this.inputTarget.value
    if (text.trim() === "") {
      const empty = document.createElement("p")
      empty.className = "text-gray-400 text-sm"
      empty.textContent = this.emptyTextValue
      this.previewTarget.replaceChildren(empty)
    } else {
      // Rendered by the server, which filters out HTML. redirect: "error" keeps a login page (after the session
      // expired) out of the preview.
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Accept": "text/html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: new URLSearchParams({ text }),
        redirect: "error"
      })
      if (response.ok) this.previewTarget.innerHTML = await response.text()
    }
    this.inputTarget.classList.add("hidden")
    this.previewTarget.classList.remove("hidden")
    this.previewTabTarget.classList.add("tab-active")
    this.writeTabTarget.classList.remove("tab-active")
  }
}
