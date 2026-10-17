import { Controller } from "@hotwired/stimulus"

// Opens and closes the assistant side panel, remembers that choice in a cookie (so the next page arrives the same
// way, without a flash), keeps the chat scrolled to the newest message, fills in a starter, and sends on Enter.
export default class extends Controller {
  static targets = ["panel", "toggle", "messages", "message", "form", "input", "submit"]

  // The panel is permanent but <body> isn't: a page restored from Turbo's cache (Back/Forward), or rendered while
  // another tab changed the cookie, follows the panel's own state. This runs when the panel arrives, because Turbo
  // moves the kept panel into the new <body> only after the controller has connected.
  panelTargetConnected() {
    this.sync(this.isOpen)
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.show(true)
    this.scrollToEnd()
    this.inputTarget.focus()
  }

  close() {
    const hadFocus = this.panelTarget.contains(document.activeElement)
    this.show(false)
    if (hadFocus && this.hasToggleTarget) this.toggleTarget.focus()
  }

  // A new chat's starter fills in the box, for the user to finish or send.
  start({ params: { text } }) {
    this.inputTarget.value = text
    this.inputTarget.focus()
  }

  // A new message (sent or received) scrolls the chat to it.
  messageTargetConnected() {
    this.scrollToEnd()
  }

  // Enter sends; Shift+Enter is a new line. The Enter that confirms an input method's text (e.g. Pinyin) isn't a
  // send: isComposing in most browsers, keyCode 229 in Safari, which ends the composition first.
  send(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing || event.keyCode === 229) return

    event.preventDefault()
    const busy = this.formTarget.getAttribute("aria-busy") === "true" // still sending the last one
    // Submitting through the Send button lets Turbo disable it until the reply to this one has been added.
    if (!busy && this.inputTarget.value.trim()) this.formTarget.requestSubmit(this.submitTarget)
  }

  sent(event) {
    if (event.detail.success) this.formTarget.reset()
  }

  // private

  get isOpen() {
    return this.hasPanelTarget && !this.panelTarget.classList.contains("hidden")
  }

  show(open) {
    this.panelTarget.classList.toggle("hidden", !open)
    this.sync(open)
    document.cookie = `assistant_open=${open ? 1 : 0}; path=/; max-age=31536000; SameSite=Lax`
  }

  sync(open) {
    document.body.classList.toggle("assistant-open", open)
    this.toggleTargets.forEach(button => button.setAttribute("aria-expanded", open))
  }

  scrollToEnd() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}
