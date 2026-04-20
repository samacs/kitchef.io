import { Controller } from "@hotwired/stimulus"

// Receives `livepreview:update` events from LivePreviewSourceController
// and mutates the storefront-preview DOM accordingly. Keeping the
// receiver decoupled from the source means the form and the preview can
// sit in sibling subtrees — their only contract is the event name and
// payload shape.
//
// Event payload: { field: "name" | "slug" | "description" | "logo" | "cover",
//                  value: string, url: string|null }
export default class extends Controller {
  static targets = ["name", "slug", "description", "logo", "logoPlaceholder", "cover", "coverPlaceholder"]
  static values  = {
    emptyName:        { type: String, default: "" },
    emptyDescription: { type: String, default: "" }
  }

  connect() {
    this.handler = (event) => this.#apply(event.detail || {})
    document.addEventListener("livepreview:update", this.handler)
  }

  disconnect() {
    document.removeEventListener("livepreview:update", this.handler)
  }

  #apply({ field, value, url }) {
    switch (field) {
      case "name":        return this.#setName(value)
      case "slug":        return this.#setSlug(value)
      case "description": return this.#setDescription(value)
      case "logo":        return this.#setImage(this.logoTarget, this.logoPlaceholderTarget, url)
      case "cover":       return this.#setImage(this.coverTarget, this.coverPlaceholderTarget, url)
    }
  }

  #setName(value) {
    if (!this.hasNameTarget) return
    const trimmed = (value || "").trim()
    if (trimmed) {
      this.nameTarget.textContent = trimmed
      this.nameTarget.dataset.empty = "false"
      this.nameTarget.classList.remove("text-muted", "italic")
      this.nameTarget.classList.add("text-ink")
    } else {
      this.nameTarget.textContent = this.emptyNameValue
      this.nameTarget.dataset.empty = "true"
      this.nameTarget.classList.add("text-muted", "italic")
      this.nameTarget.classList.remove("text-ink")
    }
  }

  #setSlug(value) {
    if (!this.hasSlugTarget) return
    const trimmed = (value || "").trim()
    this.slugTarget.textContent = trimmed || "tu-cocina"
  }

  #setDescription(value) {
    if (!this.hasDescriptionTarget) return
    const trimmed = (value || "").trim()
    if (trimmed) {
      this.descriptionTarget.textContent = trimmed
      this.descriptionTarget.dataset.empty = "false"
      this.descriptionTarget.classList.remove("text-muted", "italic")
      this.descriptionTarget.classList.add("text-ink-2")
    } else {
      this.descriptionTarget.textContent = this.emptyDescriptionValue
      this.descriptionTarget.dataset.empty = "true"
      this.descriptionTarget.classList.add("text-muted", "italic")
      this.descriptionTarget.classList.remove("text-ink-2")
    }
  }

  #setImage(imgEl, placeholderEl, url) {
    if (!imgEl || !placeholderEl) return
    if (url) {
      imgEl.src = url
      imgEl.classList.remove("hidden")
      imgEl.classList.add("block")
      placeholderEl.classList.add("hidden")
      placeholderEl.classList.remove("flex")
    } else {
      imgEl.src = ""
      imgEl.classList.add("hidden")
      imgEl.classList.remove("block")
      placeholderEl.classList.remove("hidden")
      placeholderEl.classList.add("flex")
    }
  }
}
