import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "field", "other"]

  // The date is shown, and sent, only while "Other…" is chosen
  toggle() {
    const other = this.otherTarget.checked
    this.fieldTarget.hidden = !other
    this.inputTarget.disabled = !other
  }

  snap() {
    const value = this.inputTarget.value
    if (!value) return

    const date = new Date(value + "T00:00:00")
    const day = date.getDay()
    // getDay(): 0=Sunday, 1=Monday, ..., 6=Saturday
    // We want Monday (1). Shift back to Monday.
    const diff = day === 0 ? -6 : 1 - day
    date.setDate(date.getDate() + diff)

    // Format as YYYY-MM-DD
    const yyyy = date.getFullYear()
    const mm = String(date.getMonth() + 1).padStart(2, "0")
    const dd = String(date.getDate()).padStart(2, "0")
    this.inputTarget.value = `${yyyy}-${mm}-${dd}`
  }
}
