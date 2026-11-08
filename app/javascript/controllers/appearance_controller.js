import { Controller } from "@hotwired/stimulus"

// The account menu's Light / Dark / Auto switch: turns the page at once, before the form saves the choice. The
// page's colours follow <html data-theme> (theme.css), and the phone's status bar the theme-color tag shown (see
// ApplicationHelper#theme_color_media).
export default class extends Controller {
  pick({ currentTarget: { value } }) {
    document.documentElement.dataset.theme = value
    document.querySelectorAll("meta[name=theme-color]").forEach(meta => {
      const scheme = meta.dataset.scheme
      meta.media = value === "auto" ? `(prefers-color-scheme: ${scheme})` : (value === scheme ? "all" : "not all")
    })
  }
}
