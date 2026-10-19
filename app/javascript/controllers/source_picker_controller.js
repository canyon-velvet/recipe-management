import { Controller } from "@hotwired/stimulus"

// The source picker (shared/source_picker): chips to tap, and Other… to open a search box (autocomplete, with
// inline-create for a new source). What's picked there joins the chips, checked. A source the user doesn't have yet
// (newChip) is sent by name (newName) only while its chip is checked.
export default class extends Controller {
  static targets = ["chips", "other", "search", "newChip", "newName"]
  static values = { field: String }

  connect() {
    this.changed()
  }

  other() {
    this.searchTarget.hidden = false
    this.searchInput.focus()
  }

  add({ detail: { id, name } }) {
    const radio = [...this.chipsTarget.querySelectorAll("input[type=radio]")].find((r) => r.value === String(id)) ||
      this.chip(id, name)
    radio.checked = true
    this.searchInput.value = ""
    this.searchTarget.hidden = true
    this.changed()
  }

  chip(id, name) {
    const radio = document.createElement("input")
    Object.assign(radio, { type: "radio", name: this.fieldValue, value: id, className: "sr-only", required: true })
    const label = document.createElement("label")
    label.className = "source-chip"
    label.append(radio, name)
    this.otherTarget.before(label)
    return radio
  }

  changed() {
    if (this.hasNewNameTarget) this.newNameTarget.disabled = !this.newChipTarget.checked
  }

  get searchInput() {
    return this.searchTarget.querySelector("input[type=text]")
  }
}
