import { Controller } from "@hotwired/stimulus"

// The source picker (shared/source_picker): chips to tap, and Other… to open a search box (autocomplete, with
// inline-create for a new source). What's picked there joins the chips, checked. A source the user doesn't have yet
// (newChip) is sent by name (newName) only while its chip is checked. With no chips to tap (requiredMessage), the
// search box stops the form, saying so, until a source is picked or created there. Tapping the checked chip again
// unchecks it, to pick or create another; a recipe still needs a source, so while none is checked the form stops,
// saying so (pickMessage).
export default class extends Controller {
  static targets = ["chips", "other", "search", "newChip", "newName"]
  static values = { field: String, requiredMessage: String, pickMessage: String }

  connect() {
    this.searchInput.setCustomValidity(this.requiredMessageValue)
    this.changed()
  }

  other() {
    this.searchTarget.hidden = false
    this.searchInput.focus()
  }

  add({ detail: { id, name } }) {
    const radio = this.radios.find((r) => r.value === String(id)) || this.chip(id, name)
    radio.checked = true
    this.searchInput.value = ""
    // A chip is picked now, also once Turbo restores this page from its cache (connect runs again)
    this.requiredMessageValue = ""
    this.searchInput.setCustomValidity("")
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

  // A tap on a chip: the one already checked is unchecked
  toggle({ target }) {
    if (target.type !== "radio") return
    if (target === this.checked) target.checked = false
    this.changed()
  }

  // Space on the checked chip, which browsers don't click, as they do an unchecked one. A held key repeats: the
  // chip it unchecked would be clicked, so checked again, when it's let go.
  toggleWithSpace(event) {
    if (event.target.type !== "radio") return
    if (event.repeat) return event.preventDefault()
    if (!event.target.checked) return
    event.preventDefault()
    event.target.checked = false
    this.changed()
  }

  changed() {
    this.checked = this.radios.find((radio) => radio.checked)
    if (this.hasNewNameTarget) this.newNameTarget.disabled = !this.newChipTarget.checked
    this.radios[0]?.setCustomValidity(this.checked ? "" : this.pickMessageValue)
  }

  get radios() {
    return [...this.chipsTarget.querySelectorAll("input[type=radio]")]
  }

  get searchInput() {
    return this.searchTarget.querySelector("input[type=text]")
  }
}
