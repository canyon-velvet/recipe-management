import { Controller } from "@hotwired/stimulus"

// Keeps recipe step rows' visible numbers and hidden position fields in DOM order. Reorder mode collapses each step to
// its first line, which the sortable controller drags (a row with the mouse, its handle with a finger, or ↑ ↓ on the
// focused handle).
export default class extends Controller {
  static targets = ["step", "number", "position", "preview", "handle", "toggle", "toggleLabel", "status"]
  static values = { reorderText: String, doneText: String, moveText: String, movedText: String }

  stepTargetConnected() {
    this.renumber()
  }

  toggleReorder() {
    const reordering = this.element.classList.toggle("steps--reordering")
    this.toggleTarget.setAttribute("aria-pressed", reordering)
    this.toggleLabelTarget.textContent = reordering ? this.doneTextValue : this.reorderTextValue
    this.previewTargets.forEach(preview => {
      const body = preview.closest("[data-step-list-target='step']").querySelector("textarea")
      preview.textContent = body.value || body.placeholder
    })
  }

  // After sortable moved a step
  moved({ detail: { item } }) {
    this.renumber()
    this.announce(item)
  }

  renumber() {
    this.visibleSteps().forEach((step, index) => {
      const number = index + 1
      step.querySelector("[data-step-list-target='number']").textContent = number
      step.querySelector("[data-step-list-target='position']").value = number
      step.querySelector("[data-step-list-target='handle']")
        .setAttribute("aria-label", this.moveTextValue.replace("%{number}", number))
    })
  }

  // Tells screen readers where a moved step now is, e.g. "Step moved to 3 of 8"
  announce(step) {
    const steps = this.visibleSteps()
    this.statusTarget.textContent = this.movedTextValue
      .replace("%{number}", steps.indexOf(step) + 1).replace("%{total}", steps.length)
  }

  visibleSteps() {
    return this.stepTargets.filter(step => !step.classList.contains("hidden"))
  }
}
