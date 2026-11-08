// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Turbo Drive swaps <body> and merges <head>, but of <html> keeps only lang and dir. The page's colours (data-theme,
// the account menu's Light / Dark / Auto) come from each new page too, as its status bar colour does: after logging
// out, or a choice made on another device. The new <body> carries them (data-appearance).
addEventListener("turbo:before-render", ({ detail: { newBody } }) => {
  document.documentElement.dataset.theme = newBody.dataset.appearance
})
