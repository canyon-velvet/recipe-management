import { Controller } from "@hotwired/stimulus"

const EDGE = 60 // how near the top or bottom of the screen a drag scrolls the page
const NUDGE = 8 // how far the pointer moves before edge scrolling starts, so a press on an item near an edge stays put

// Puts its items in order by dragging them, with the mouse or a finger, or with ↑ ↓ on a focused handle. A handle
// takes pointerdown->sortable#drag and keydown->sortable#moveWithKeys; a part with data-sortable-mouse-only-param
// drags only with a mouse, so a finger can scroll the page over it. Hidden items (class "hidden") are skipped. When
// an item lands somewhere new it fires "sortable:moved" with the item, where it was and is, and how many there are.
export default class extends Controller {
  static targets = ["item"]
  static classes = ["lifted"]

  disconnect() {
    if (this.dragged) this.dragEnd()
  }

  // One drag at a time, following only the pointer that started it (a second finger is ignored)
  drag(event) {
    if (this.dragged || event.button > 0) return
    if (event.params.mouseOnly && event.pointerType !== "mouse") return
    event.preventDefault()
    this.dragged = this.itemFor(event)
    if (this.hasLiftedClass) this.dragged.classList.add(this.liftedClass)
    this.pointerId = event.pointerId
    this.pointerY = this.startY = event.clientY
    this.startIndex = this.items().indexOf(this.dragged)
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
    const others = this.items().filter(item => item !== this.dragged)
    const before = others.find(item => {
      const rect = item.getBoundingClientRect()
      return y < rect.top + rect.height / 2
    })
    const after = others.at(-1)
    if (!after || this.nextItem(this.dragged) === before) return

    this.slide(() => before ? before.before(this.dragged) : after.after(this.dragged))
  }

  dragEnd() {
    document.removeEventListener("pointermove", this.onDragMove)
    document.removeEventListener("pointerup", this.onDragEnd)
    document.removeEventListener("pointercancel", this.onDragEnd)
    cancelAnimationFrame(this.scrollFrame)
    if (this.hasLiftedClass) this.dragged.classList.remove(this.liftedClass)
    this.moved(this.dragged, this.startIndex)
    this.dragged = null
  }

  // While the pointer is held near the top (below the sticky header) or the bottom of the screen, scrolls the page and
  // keeps the dragged item under the pointer
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

  // ↑ ↓ on a focused handle move its item, keeping the focus on the handle
  moveWithKeys(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return
    event.preventDefault()
    const item = this.itemFor(event)
    const items = this.items()
    const index = items.indexOf(item)
    if (event.key === "ArrowUp" && index > 0) items[index - 1].before(item)
    if (event.key === "ArrowDown" && index < items.length - 1) items[index + 1].after(item)
    event.currentTarget.focus()
    this.moved(item, index)
  }

  moved(item, from) {
    const items = this.items()
    const to = items.indexOf(item)
    if (to !== from) this.dispatch("moved", { detail: { item, from, to, total: items.length } })
  }

  // Animates the other items from where they were to where they are now, so they slide rather than jump
  slide(move) {
    const others = this.items().filter(item => item !== this.dragged)
    const tops = new Map(others.map(item => [ item, item.getBoundingClientRect().top ]))
    move()
    others.forEach(item => {
      const shift = tops.get(item) - item.getBoundingClientRect().top
      if (shift) item.animate([ { transform: `translateY(${shift}px)` }, { transform: "none" } ], 150)
    })
  }

  nextItem(item) {
    const items = this.items()
    return items[items.indexOf(item) + 1]
  }

  itemFor(event) {
    return event.currentTarget.closest("[data-sortable-target='item']")
  }

  items() {
    return this.itemTargets.filter(item => !item.classList.contains("hidden"))
  }
}
