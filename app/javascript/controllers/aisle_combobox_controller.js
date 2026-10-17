import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

// The create-ingredient pop-up's aisle box: type to search the aisles, or pick "Add …" to create the typed one as a new
// aisle (just before Other), which is then chosen and stays in the list. Closing the pop-up empties it.
export default class extends Controller {
  static targets = ["select", "error"]
  static values = { createUrl: String, addText: String, errorText: String }

  connect() {
    this.tomSelect = new TomSelect(this.selectTarget, {
      create: (name, callback) => this.createAisle(name).then(callback),
      // "Add …" only for a name no aisle has yet (the options' values are ids, so the default check can't tell)
      createFilter: (input) => !this.aisleNamed(input),
      refreshThrottle: 0, // the list matches what's typed before Enter can pick from it
      maxOptions: null,
      render: {
        option_create: (data) => {
          const div = document.createElement("div")
          div.className = "create"
          div.textContent = this.addTextValue.replace("%{name}", () => data.input)
          return div
        },
        no_results: () => null // "Add …" is there instead
      }
    })
    this.reset = () => this.clear()
    this.dialog = this.element.closest("dialog")
    this.dialog?.addEventListener("close", this.reset)
  }

  disconnect() {
    this.dialog?.removeEventListener("close", this.reset)
    this.tomSelect?.destroy()
  }

  aisleNamed(name) {
    const wanted = name.trim().toLowerCase()
    return Object.values(this.tomSelect.options).some(option => option.text.toLowerCase() === wanted)
  }

  // Resolves with the new aisle for Tom Select to add and choose, or with nothing (and says why) if it wasn't created.
  // One at a time: a second Add while the first is saving is ignored.
  async createAisle(name) {
    if (this.creating) return
    this.creating = true
    this.errorTarget.textContent = ""
    try {
      const body = new FormData()
      body.append("aisle[name]", name)
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
        body
      })
      const data = await response.json()
      if (response.ok) return { value: String(data.id), text: data.name }
      this.errorTarget.textContent = data.errors?.join(", ") || this.errorTextValue
    } catch {
      this.errorTarget.textContent = this.errorTextValue
    } finally {
      this.creating = false
    }
  }

  clear() {
    this.tomSelect.clear(true)
    this.errorTarget.textContent = ""
  }
}
