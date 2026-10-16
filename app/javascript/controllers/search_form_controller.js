import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // link (optional): links that keep the search, such as the recipe catalog's tags
  static targets = ["form", "link"]

  submitLater() {
    this.#keepQueryInLinks()
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.formTarget.requestSubmit(), 350)
  }

  // Following a link: the search it carries goes with it, so the one still waiting isn't sent as well. A click
  // anywhere else (a heading, a dimmed tag) leaves the search to go.
  cancelSearch(event) {
    if (event.target.closest("a")) clearTimeout(this.timeout)
  }

  // A search into a frame came back without it (the login page, once the session has ended): show that page whole
  showWholePage(event) {
    event.preventDefault()
    event.detail.visit(event.detail.response)
  }

  // The links take the search box's text as it is now, however they're opened (click, new tab…): searching may reload
  // only the results, not the links.
  #keepQueryInLinks() {
    const query = this.formTarget.elements.q.value.trim()
    this.linkTargets.forEach(link => {
      const url = new URL(link.href)
      if (query) url.searchParams.set("q", query)
      else url.searchParams.delete("q")
      link.href = url
    })
  }
}
