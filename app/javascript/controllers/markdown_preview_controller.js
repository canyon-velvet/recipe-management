import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "writeTab", "previewTab"]
  static values = { emptyText: String, failedText: String, url: String }

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
    this.inputTarget.classList.add("hidden")
    this.previewTarget.classList.remove("hidden")
    this.previewTabTarget.classList.add("tab-active")
    this.writeTabTarget.classList.remove("tab-active")

    if (text.trim() === "") return this.showMessage(this.emptyTextValue)

    this.previewTarget.replaceChildren()
    let html = null
    try {
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
      if (response.ok) html = await response.text()
    } catch {
      // Offline, or the session expired: shown below as a failed preview.
    }
    // Back on Write, or the text changed and a newer preview is on its way: this one is stale.
    if (!this.showingPreview || this.inputTarget.value !== text) return

    if (html === null) {
      this.showMessage(this.failedTextValue)
    } else {
      this.previewTarget.innerHTML = html
    }
  }

  get showingPreview() {
    return !this.previewTarget.classList.contains("hidden")
  }

  showMessage(message) {
    const note = document.createElement("p")
    note.className = "text-gray-400 text-sm"
    note.textContent = message
    this.previewTarget.replaceChildren(note)
  }
}
