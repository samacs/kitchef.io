import { Controller } from "@hotwired/stimulus"

// Receives `livepreview:update` events from LivePreviewSourceController
// and mutates the storefront-preview DOM accordingly. Keeping the
// receiver decoupled from the source means the form and the preview can
// sit in sibling subtrees — their only contract is the event name and
// payload shape.
//
// Event payload: { field, value, url }
//   field: "name" | "tagline" | "description" | "logo" | "cover"
//        | "palette" | "secondary_palette" | "theme_default"
//   value: string (for text/radio) or filename (for file) or null
//   url:   data URL (for file) or null
//
// The palette lookup table is injected via `data-live-preview-palettes-value`
// on the root element so we never ship a duplicate client-side copy of
// `Storefronts::Palette::PALETTES` — the server renders the same JSON
// into a single `data-` attribute at response time.
export default class extends Controller {
  static targets = [
    "name", "slug", "tagline", "description",
    "logo", "logoPlaceholder",
    "cover", "coverPlaceholder"
  ]

  static values = {
    emptyName:        { type: String, default: "" },
    emptyTagline:     { type: String, default: "" },
    emptyDescription: { type: String, default: "" },
    palettes:         { type: Object, default: {} }
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
      case "name":              return this.#setName(value)
      case "slug":              return this.#setSlug(value)
      case "tagline":           return this.#setTagline(value)
      case "description":       return this.#setDescription(value)
      case "logo":              return this.#setImage(this.logoTarget, this.logoPlaceholderTarget, url)
      case "cover":             return this.#setImage(this.coverTarget, this.coverPlaceholderTarget, url)
      case "palette":           return this.#setPalette(value, 1)
      case "secondary_palette": return this.#setPalette(value, 2)
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

  #setTagline(value) {
    if (!this.hasTaglineTarget) return
    const trimmed = (value || "").trim()
    if (trimmed) {
      this.taglineTarget.textContent = trimmed
      this.taglineTarget.classList.remove("italic", "text-muted")
      this.taglineTarget.classList.add("text-ink-2")
    } else if (this.emptyTaglineValue) {
      this.taglineTarget.textContent = this.emptyTaglineValue
      this.taglineTarget.classList.add("italic", "text-muted")
      this.taglineTarget.classList.remove("text-ink-2")
    } else {
      // No placeholder configured — hide the element so the preview
      // doesn't leave a dangling empty line.
      this.taglineTarget.textContent = ""
    }
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

  // Palette change — rewrite the --brand-N-* custom properties on the
  // preview root so every child that consumes them (cover gradient,
  // hero CTA, zone chips) updates without touching individual nodes.
  // `which` is 1 (primary) or 2 (secondary). The preview always
  // renders in the light variant (the operator app is always-light
  // chrome); the public storefront responds to the customer's
  // preference independently.
  #setPalette(name, which) {
    if (!name) return
    const entry = this.palettesValue[name]
    if (!entry || !entry.light) return
    const variant = entry.light
    const root = this.element
    root.style.setProperty(`--brand-${which}`,      variant.c)
    root.style.setProperty(`--brand-${which}-ink`,  variant.ink)
    root.style.setProperty(`--brand-${which}-soft`, variant.soft)
    root.style.setProperty(`--brand-${which}-line`, variant.line)
  }
}
