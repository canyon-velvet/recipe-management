import { Controller } from "@hotwired/stimulus"

// Reusable controller for inline-create modals (ingredients, sources, etc.)
// Collects all named inputs inside the dialog and POSTs as FormData.
export default class extends Controller {
  static targets = ["dialog", "errors", "prefill"]
  static values = { createUrl: String, errorText: String }

  openModal(event) {
    this.triggerAutocomplete = event.target.closest("[data-controller*='autocomplete']")
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
        if (el.type === "checkbox") {
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
      if (el.type === "checkbox") {
        el.checked = false
      } else if (el.tagName === "SELECT") {
        el.selectedIndex = 0
      } else {
        el.value = ""
      }
    })
  }
}
