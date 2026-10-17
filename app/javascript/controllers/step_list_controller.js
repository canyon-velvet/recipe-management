import { Controller } from "@hotwired/stimulus"

const EDGE = 60 // how near the top or bottom of the screen a drag scrolls the page
const NUDGE = 8 // how far the pointer moves before edge scrolling starts, so a press on a row near an edge stays put

// Reorders recipe step rows and keeps their visible numbers and hidden position fields in DOM order. Reorder mode
// collapses each step to its first line: drag a row with the mouse or a finger, or focus its handle and use ↑ ↓.
export default class extends Controller {
  static targets = ["step", "number", "position", "preview", "handle", "toggle", "toggleLabel", "status"]
  static values = { reorderText: String, doneText: String, moveText: String, movedText: String }

  stepTargetConnected() {
    this.renumber()
  }

  disconnect() {
    if (this.dragged) this.dragEnd()
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

  // One drag at a time, following only the pointer that started it (a second finger is ignored)
  startDrag(event) {
    if (this.dragged || event.button > 0) return
    event.preventDefault()
    this.dragged = this.stepFor(event)
    this.dragged.classList.add("step-row--lifted")
    this.pointerId = event.pointerId
    this.pointerY = this.startY = event.clientY
    this.startIndex = this.visibleSteps().indexOf(this.dragged)
    this.nudged = false
    this.onDragMove = (e) => { if (e.pointerId === this.pointerId) this.dragMove(e.clientY) }
    this.onDragEnd = (e) => { if (e.pointerId === this.pointerId) this.dragEnd() }
    document.addEventListener("pointermove", this.onDragMove)
    document.addEventListener("pointerup", this.onDragEnd)
    document.addEventListener("pointercancel", this.onDragEnd)
    this.scrollFrame = requestAnimationFrame(() => this.scrollNearEdge())
  }

  dragMove(y) {
    this.pointerY = y
    const others = this.visibleSteps().filter(step => step !== this.dragged)
    const before = others.find(step => {
      const rect = step.getBoundingClientRect()
      return y < rect.top + rect.height / 2
    })
    const after = others.at(-1)
    if (!after || this.nextVisibleStep(this.dragged) === before) return

    this.slide(() => before ? before.before(this.dragged) : after.after(this.dragged))
  }

  dragEnd() {
    document.removeEventListener("pointermove", this.onDragMove)
    document.removeEventListener("pointerup", this.onDragEnd)
    document.removeEventListener("pointercancel", this.onDragEnd)
    cancelAnimationFrame(this.scrollFrame)
    this.dragged.classList.remove("step-row--lifted")
    this.renumber()
    if (this.visibleSteps().indexOf(this.dragged) !== this.startIndex) this.announce(this.dragged)
    this.dragged = null
  }

  // While the pointer is held near the top (below the sticky header) or the bottom of the screen, scrolls the page and
  // keeps the dragged step under the pointer
  scrollNearEdge() {
    this.nudged ||= Math.abs(this.pointerY - this.startY) > NUDGE
    const top = document.querySelector("header")?.getBoundingClientRect().bottom ?? 0
    const scroll = this.pointerY < top + EDGE ? -10 : this.pointerY > window.innerHeight - EDGE ? 10 : 0
    if (scroll && this.nudged) {
      window.scrollBy(0, scroll)
      this.dragMove(this.pointerY)
    }
    this.scrollFrame = requestAnimationFrame(() => this.scrollNearEdge())
  }

  // ↑ ↓ on a focused handle move its step, keeping the focus on the handle
  moveWithKeys(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return
    event.preventDefault()
    const step = this.stepFor(event)
    const steps = this.visibleSteps()
    const index = steps.indexOf(step)
    if (event.key === "ArrowUp" && index > 0) steps[index - 1].before(step)
    if (event.key === "ArrowDown" && index < steps.length - 1) steps[index + 1].after(step)
    event.currentTarget.focus()
    this.renumber()
    this.announce(step)
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

  // Animates the other steps from where they were to where they are now, so they slide rather than jump
  slide(move) {
    const others = this.visibleSteps().filter(step => step !== this.dragged)
    const tops = new Map(others.map(step => [ step, step.getBoundingClientRect().top ]))
    move()
    others.forEach(step => {
      const shift = tops.get(step) - step.getBoundingClientRect().top
      if (shift) step.animate([ { transform: `translateY(${shift}px)` }, { transform: "none" } ], 150)
    })
  }

  nextVisibleStep(step) {
    const steps = this.visibleSteps()
    return steps[steps.indexOf(step) + 1]
  }

  stepFor(event) {
    return event.currentTarget.closest("[data-step-list-target='step']")
  }

  visibleSteps() {
    return this.stepTargets.filter(step => !step.classList.contains("hidden"))
  }
}
