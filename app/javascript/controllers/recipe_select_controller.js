import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["dialog", "input", "results", "slotId"]
  static values = { searchUrl: String, promptText: String, noResultsText: String }

  connect() {
    this.timeout = null
  }

  openForSlot(event) {
    const slotId = event.currentTarget.dataset.mealSlotId
    this.slotIdTarget.value = slotId
    this.inputTarget.value = ""
    this.showMessage(this.promptTextValue)
    this.dialogTarget.showModal()
    this.inputTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  onInput() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length === 0) {
      this.showMessage(this.promptTextValue)
      return
    }

    this.timeout = setTimeout(() => this.fetchResults(query), 250)
  }

  async fetchResults(query) {
    const url = `${this.searchUrlValue}?q=${encodeURIComponent(query)}`
    const response = await fetch(url, {
      headers: { "Accept": "application/json" }
    })
    const recipes = await response.json()
    this.renderResults(recipes)
  }

  renderResults(recipes) {
    if (recipes.length === 0) {
      this.showMessage(this.noResultsTextValue)
      return
    }

    this.resultsTarget.replaceChildren(...recipes.map(recipe => this.buildResult(recipe)))
  }

  buildResult(recipe) {
    const li = document.createElement("li")
    li.className = "group flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer hover:bg-sectiontext-light transition-colors"
    li.dataset.action = "click->recipe-select#select"
    li.dataset.recipeId = recipe.id

    const name = document.createElement("span")
    name.className = "text-sm text-gray-800 group-hover:text-white"
    name.textContent = recipe.name

    const tags = document.createElement("span")
    tags.className = "text-xs text-gray-400 group-hover:text-white/80"
    tags.textContent = recipe.tags.join(" · ")

    li.append(name, tags)
    return li
  }

  async select(event) {
    const recipeId = event.currentTarget.dataset.recipeId
    const slotId = this.slotIdTarget.value
    const url = `/meal_slots/${slotId}/meal_slot_recipes`

    try {
      const response = await this.turboFetch(url, "POST", {
        "meal_slot_recipe[recipe_id]": recipeId
      })
      if (response.ok) {
        Turbo.renderStreamMessage(await response.text())
        this.close()
      }
    } catch (error) {
      console.error("Failed to add recipe:", error)
    }
  }

  async toggleGrocery(event) {
    const checkbox = event.currentTarget
    const url = checkbox.dataset.url

    try {
      const response = await this.turboFetch(url, "PATCH", {
        "meal_slot_recipe[add_to_grocery_list]": checkbox.checked
      })
      if (response.ok) {
        Turbo.renderStreamMessage(await response.text())
      }
    } catch (error) {
      console.error("Failed to toggle grocery:", error)
    }
  }

  // Helpers

  showMessage(text) {
    const li = document.createElement("li")
    li.className = "text-sm text-gray-400 text-center py-4"
    li.textContent = text
    this.resultsTarget.replaceChildren(li)
  }

  turboFetch(url, method, params) {
    const formData = new FormData()
    Object.entries(params).forEach(([k, v]) => formData.append(k, v))

    return fetch(url, {
      method,
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: formData
    })
  }
}
