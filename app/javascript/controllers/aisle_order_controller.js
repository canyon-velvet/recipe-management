import { Controller } from "@hotwired/stimulus"

// Saves an aisle's new place after sortable moves it, and tells screen readers where it went. Saves go one at a time,
// in order, so quick moves land as made. If one fails the list reloads to show the saved order. The pop-up
// (aisle-editor) counts each save like a form's, so closing it waits for them; the events go to the pop-up itself,
// which is still there if the list reloads (after a rename) before a save ends.
export default class extends Controller {
  static targets = ["status"]
  static values = { movedText: String }

  moved({ detail: { item, to, total } }) {
    // Replacer functions, so a "$" in a name is taken as it is
    this.statusTarget.textContent = this.movedTextValue
      .replace("%{name}", () => item.dataset.name).replace("%{number}", to + 1).replace("%{total}", total)
    const popUp = this.element.closest("dialog") ?? this.element
    const list = this.element.closest("turbo-frame")
    this.dispatch("save-start", { target: popUp })
    this.saving = (this.saving ?? Promise.resolve()).then(async () => {
      const success = await this.save(item.dataset.moveUrl, to)
      this.dispatch("save-end", { target: popUp, detail: { success } })
      if (!success) list?.reload()
    })
  }

  async save(url, position) {
    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
        body: new URLSearchParams({ position }),
        redirect: "error"
      })
      return response.ok
    } catch {
      return false // offline, or the session expired
    }
  }
}
