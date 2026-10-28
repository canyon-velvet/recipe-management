import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

// Turns a <select multiple> into a searchable tag picker with removable pills. A tag typed that isn't there is offered
// to create (createLabel, with %{name} for what was typed): that asks the New tag pop-up (inline-create) to open, and
// the tag it creates is added and picked.
export default class extends Controller {
  static values = { noResults: String, removeLabel: String, createLabel: String }

  connect() {
    this.tomSelect = new TomSelect(this.element, {
      plugins: { remove_button: { title: this.removeLabelValue } },
      create: (input, callback) => {
        this.dispatch("requestCreate", { detail: { query: input } })
        callback() // nothing added yet: the pop-up adds the tag once it's saved
      },
      // Only a tag that isn't there, by name (each option's data-data); a comma is part of the name typed
      createFilter: (input) => this.isNewName(input),
      delimiter: null,
      persist: false,
      maxOptions: null,
      render: {
        // Not with the offer to create the tag typed: it says the rest
        no_results: (data) => (this.tomSelect.canCreate(data.input) ? null : this.noResultsElement()),
        option_create: (data) => this.createElement(data.input)
      }
    })
  }

  disconnect() {
    this.tomSelect?.destroy()
  }

  // The tag the New tag pop-up created: { id, name, label }
  created({ detail: tag }) {
    this.tomSelect.addOption({ value: String(tag.id), text: tag.label, name: tag.name })
    this.tomSelect.addItem(String(tag.id))
  }

  isNewName(input) {
    const name = input.trim().toLowerCase()
    return name !== "" && !Object.values(this.tomSelect.options).some(option => option.name?.toLowerCase() === name)
  }

  noResultsElement() {
    const div = document.createElement("div")
    div.className = "no-results"
    div.textContent = this.noResultsValue
    return div
  }

  // textContent, so what was typed is shown as text
  createElement(input) {
    const div = document.createElement("div")
    div.className = "create"
    div.textContent = this.createLabelValue.replace("%{name}", () => input) // a function: a $ typed stays a $
    return div
  }
}
