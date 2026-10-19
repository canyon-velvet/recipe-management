import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  async togglePantry(event) {
    const checkbox = event.currentTarget
    const url = checkbox.dataset.groceryListUrlParam
    const inPantry = checkbox.dataset.groceryListPantryParam

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: new URLSearchParams({ in_pantry: inPantry })
      })

      // Only if it is streams: a fetch that followed a redirect to the login page gets that page instead
      if (response.ok && response.headers.get("content-type")?.includes("turbo-stream")) {
        Turbo.renderStreamMessage(await response.text())
      }
    } catch (error) {
      console.error("Failed to toggle pantry:", error)
      checkbox.checked = !checkbox.checked
    }
  }
}
