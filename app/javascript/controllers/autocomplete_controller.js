import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenField", "list"]
  static values = {
    url: String,
    createLabel: String
  }

  connect() {
    this.timeout = null
  }

  onInput() {
    this.hiddenFieldTarget.value = ""
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length === 0) {
      this.hideList()
      return
    }

    this.timeout = setTimeout(() => this.fetchResults(query), 250)
  }

  async fetchResults(query) {
    const url = `${this.urlValue}?q=${encodeURIComponent(query)}`
    const response = await fetch(url, {
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      }
    })
    const results = await response.json()
    this.renderList(results)
  }

  renderList(results) {
    const list = this.listTarget
    list.innerHTML = ""

    // "Create new" option always first
    const createLi = document.createElement("li")
    createLi.textContent = this.createLabelValue
    createLi.classList.add("autocomplete-item", "autocomplete-item--create")
    createLi.setAttribute("data-action", "click->autocomplete#createNew")
    list.appendChild(createLi)

    results.forEach(item => {
      const li = document.createElement("li")
      li.textContent = item.name
      li.classList.add("autocomplete-item")
      li.setAttribute("data-id", item.id)
      li.setAttribute("data-name", item.name)
      li.setAttribute("data-action", "click->autocomplete#select")
      list.appendChild(li)
    })

    list.classList.remove("hidden")
  }

  select(event) {
    const { id, name } = event.currentTarget.dataset
    this.setSelection(id, name)
  }

  // Also sent as autocomplete:selected, for a picker that shows the choice its own way (the source picker's chips)
  setSelection(id, name) {
    this.inputTarget.value = name
    this.hiddenFieldTarget.value = id
    this.hideList()
    this.dispatch("selected", { detail: { id, name } })
  }

  createNew() {
    this.hideList()
    this.dispatch("requestCreate", {
      detail: { query: this.inputTarget.value.trim() }
    })
  }

  outside(event) {
    if (!this.element.contains(event.target)) {
      this.hideList()
    }
  }

  hideList() {
    this.listTarget.classList.add("hidden")
  }
}
