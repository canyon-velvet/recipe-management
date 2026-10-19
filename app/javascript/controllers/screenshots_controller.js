import { Controller } from "@hotwired/stimulus"

// Screenshot, in the import form. The picked pictures are shrunk on the phone, to LONG_SIDE pixels on their long side
// as JPEG, so they upload quickly; they show as thumbnails to remove or add to, in the order they'll be read.
const LONG_SIDE = 1600

export default class extends Controller {
  static targets = ["input", "picker", "list", "add", "submit"]
  static values = { max: Number, removeLabel: String }

  connect() {
    this.shots = []
  }

  disconnect() {
    this.shots.forEach(({ url }) => URL.revokeObjectURL(url))
  }

  // The picker's choice replaces the input's files; they're added to the ones picked before. Until they're shrunk,
  // neither another pick nor Import can start, so what's sent is always every shrunk picture, in order.
  async add() {
    this.busy(true)
    try {
      const picked = [...this.inputTarget.files].slice(0, this.maxValue - this.shots.length)
      const files = await Promise.all(picked.map(shrink))
      this.shots.push(...files.map((file) => ({ file, url: URL.createObjectURL(file) })))
    } finally {
      this.update()
      this.busy(false)
    }
  }

  busy(busy) {
    this.inputTarget.disabled = busy
    this.submitTarget.disabled = busy
  }

  remove({ params: { index } }) {
    const [removed] = this.shots.splice(index, 1)
    URL.revokeObjectURL(removed.url)
    this.update()
  }

  update() {
    const transfer = new DataTransfer()
    this.shots.forEach(({ file }) => transfer.items.add(file))
    this.inputTarget.files = transfer.files

    this.listTarget.replaceChildren(...this.shots.map(({ url }, index) => this.thumbnail(url, index)))
    this.pickerTarget.classList.toggle("import-shots--picked", this.shots.length > 0)
    this.addTarget.hidden = this.shots.length >= this.maxValue
  }

  thumbnail(url, index) {
    const item = document.createElement("li")
    item.className = "import-shot"
    const image = document.createElement("img")
    image.src = url
    image.alt = ""
    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "import-shot-remove"
    remove.textContent = "×"
    remove.setAttribute("aria-label", `${this.removeLabelValue} ${index + 1}`)
    remove.dataset.action = "screenshots#remove"
    remove.dataset.screenshotsIndexParam = index
    item.append(image, remove)
    return item
  }
}

// A picture the browser can't draw (a format it doesn't know) is sent as it is; the server says if it can't be read.
async function shrink(file) {
  try {
    const bitmap = await createImageBitmap(file)
    const scale = Math.min(1, LONG_SIDE / Math.max(bitmap.width, bitmap.height))
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(bitmap.width * scale)
    canvas.height = Math.round(bitmap.height * scale)
    canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.85))
    return new File([blob], file.name.replace(/\.\w+$/, "") + ".jpg", { type: "image/jpeg" })
  } catch {
    return file
  }
}
