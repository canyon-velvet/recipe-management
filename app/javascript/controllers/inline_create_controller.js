import { Controller } from "@hotwired/stimulus"

// Reusable controller for inline-create modals (ingredients, sources, tags)
// Collects all named inputs inside the dialog and POSTs as FormData. What was created goes back to the autocomplete
// that asked for it, and as an inline-create:created event (the JSON as its detail) to whatever asked.
export default class extends Controller {
  static targets = ["dialog", "errors", "prefill"]
  // resetOnOpen: each opening starts afresh, not with what was chosen before a Cancel (the New tag pop-up)
  static values = { createUrl: String, errorText: String, resetOnOpen: Boolean }

  openModal(event) {
    this.trigger = event.target
    this.triggerAutocomplete = event.target.closest("[data-controller*='autocomplete']")
    if (this.resetOnOpenValue) this.resetForm()
    if (this.hasPrefillTarget) {
      this.prefillTarget.value = event.detail.query || ""
    }
    this.errorsTarget.textContent = ""
    this.dialogTarget.showModal()
  }

  closeModal() {
    this.dialogTarget.close()
  }

  // The pop-up sits inside the recipe form, so Enter in one of its boxes would submit the recipe. It saves the pop-up
  // instead, unless the aisle box already used the Enter (to pick or add an aisle). The Enter that confirms an input
  // method's text (e.g. Pinyin) isn't a save: isComposing in most browsers, keyCode 229 in Safari.
  submitOnEnter(event) {
    if (event.defaultPrevented || event.target.tagName !== "INPUT") return
    if (event.isComposing || event.keyCode === 229) return
    this.save(event)
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) {
      this.closeModal()
    }
  }

  async save(event) {
    event.preventDefault()

    try {
      const formData = new FormData()
      this.dialogTarget.querySelectorAll("input[name], select[name], textarea[name]").forEach(el => {
        if (el.type === "checkbox" || el.type === "radio") {
          if (el.checked) formData.append(el.name, el.value)
        } else {
          formData.append(el.name, el.value)
        }
      })

      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: formData
      })

      if (response.ok) {
        const data = await response.json()
        const autocompleteCtrl = this.application.getControllerForElementAndIdentifier(
          this.triggerAutocomplete, "autocomplete"
        )
        if (autocompleteCtrl) {
          autocompleteCtrl.setSelection(data.id, data.name)
        }
        this.dispatch("created", { target: this.trigger, detail: data })
        this.closeModal()
        this.resetForm()
      } else {
        const data = await response.json()
        this.errorsTarget.textContent = data.errors ? data.errors.join(", ") : this.errorTextValue
      }
    } catch (error) {
      console.error("Inline create error:", error)
      this.errorsTarget.textContent = this.errorTextValue
    }
  }

  resetForm() {
    this.dialogTarget.querySelectorAll("input[name], select[name], textarea[name]").forEach(el => {
      if (el.type === "checkbox" || el.type === "radio") {
        el.checked = el.defaultChecked
      } else if (el.tagName === "SELECT") {
        el.selectedIndex = 0
      } else {
        el.value = ""
      }
    })
  }
}
