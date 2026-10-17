import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async togglePantry(event) {
    const checkbox = event.currentTarget
    const url = checkbox.dataset.groceryListUrlParam
    const inPantry = checkbox.dataset.groceryListPantryParam

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: new URLSearchParams({ in_pantry: inPantry })
      })

      if (response.ok) {
        const html = response.headers.get("content-type")?.includes("turbo-stream")
          ? await response.text()
          : null

        if (html) {
          const template = document.createElement("template")
          template.innerHTML = html
          template.content.querySelectorAll("turbo-stream").forEach(stream => {
            const action = stream.getAttribute("action")
            const targetId = stream.getAttribute("target")
            const target = document.getElementById(targetId)
            const content = stream.querySelector("template")?.content.cloneNode(true)

            if (action === "remove" && target) {
              target.remove()
            } else if (action === "append" && target && content) {
              target.appendChild(content)
            } else if (action === "update" && target && content) {
              target.replaceChildren(...content.childNodes)
            }
          })
        }
      }
    } catch (error) {
      console.error("Failed to toggle pantry:", error)
      checkbox.checked = !checkbox.checked
    }
  }
}
