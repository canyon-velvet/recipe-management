import { Controller } from "@hotwired/stimulus"

// Keeps a form's reorderable rows' hidden position fields (and visible numbers, if they have them) in DOM order.
// Reorder mode (reorder.css) collapses each row to a one-line preview of its fields marked data-reorder-list-preview,
// which the sortable controller drags (a row with the mouse, its handle with a finger, or ↑ ↓ on the focused handle).
export default class extends Controller {
  static targets = ["item", "number", "position", "preview", "handle", "toggle", "toggleLabel", "status"]
  static values = { reorderText: String, doneText: String, moveText: String, movedText: String }

  itemTargetConnected() {
    this.renumber()
  }

  toggleReorder() {
    const reordering = this.element.classList.toggle("reorder-list--reordering")
    this.toggleTarget.setAttribute("aria-pressed", reordering)
    this.toggleLabelTarget.textContent = reordering ? this.doneTextValue : this.reorderTextValue
    this.previewTargets.forEach(preview => {
      const fields = [...this.itemFor(preview).querySelectorAll("[data-reorder-list-preview]")]
      preview.textContent = fields.map(field => field.value).filter(Boolean).join(" ") || fields[0].placeholder
    })
  }

  // After sortable moved a row
  moved({ detail: { item } }) {
    this.renumber()
    this.announce(item)
  }

  renumber() {
    this.visibleItems().forEach((item, index) => {
      const number = index + 1
      const badge = item.querySelector("[data-reorder-list-target='number']")
      if (badge) badge.textContent = number
      item.querySelector("[data-reorder-list-target='position']").value = number
      item.querySelector("[data-reorder-list-target='handle']")
        .setAttribute("aria-label", this.moveTextValue.replace("%{number}", number))
    })
  }

  // Tells screen readers where a moved row now is, e.g. "Step moved to 3 of 8"
  announce(item) {
    const items = this.visibleItems()
    this.statusTarget.textContent = this.movedTextValue
      .replace("%{number}", items.indexOf(item) + 1).replace("%{total}", items.length)
  }

  itemFor(element) {
    return element.closest("[data-reorder-list-target~='item']")
  }

  visibleItems() {
    return this.itemTargets.filter(item => !item.classList.contains("hidden"))
  }
}
