import { Controller } from "@hotwired/stimulus"

// The import form's ways in (Link, Screenshot, Text): each panel of fields (helpers/imports_helper.rb) is enabled, and
// so shown, sent and checked, only while one of its ways is chosen.
export default class extends Controller {
  static targets = ["mode", "panel"]

  connect() {
    this.modeChanged()
  }

  modeChanged() {
    const mode = this.modeTargets.find((radio) => radio.checked)?.value
    this.panelTargets.forEach((panel) => { panel.disabled = !panel.dataset.modes.split(" ").includes(mode) })
  }
}
