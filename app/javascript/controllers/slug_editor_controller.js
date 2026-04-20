import { Controller } from "@hotwired/stimulus"

// Pairs the "kitchen name" text field with the editable slug field on the
// onboarding kitchen step. The controller handles:
//
//   1. Auto-deriving a slug from the name until the operator edits the
//      slug field by hand (once dirty, the slug stays fixed — we don't
//      clobber deliberate choices).
//   2. Debounced availability checks against the JSON endpoint, so the
//      operator sees "Disponible / Ya está en uso / Reservado" feedback
//      within ~300ms of stopping typing.
//   3. Disabling the submit button when the slug is invalid or taken —
//      the server also enforces the same rules, but a disabled submit
//      avoids round-tripping obviously-broken input.
//
// Every user-facing string is passed in from the server via the
// `statusLabels` JSON value. No copy lives in this file.
export default class extends Controller {
  static targets = ["nameInput", "slugInput", "status", "submit"]
  static values = {
    checkUrl:     String,
    statusLabels: { type: Object, default: {} },
    debounce:     { type: Number, default: 300 }
  }

  connect() {
    this.slugDirty = this.slugInputTarget.value.trim().length > 0
    this.abortController = null
    this.checkTimer = null
    this.#runCheck()
  }

  disconnect() {
    if (this.abortController) this.abortController.abort()
    if (this.checkTimer) clearTimeout(this.checkTimer)
  }

  nameChanged() {
    if (!this.slugDirty) {
      this.slugInputTarget.value = this.#slugify(this.nameInputTarget.value)
      // Programmatic dispatch — the preview listens for `input` to keep
      // the storefront preview in sync. We use `isTrusted` in slugChanged
      // to distinguish this from a real keystroke so we don't flip the
      // dirty flag and freeze auto-sync.
      this.slugInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.#scheduleCheck()
  }

  slugChanged(event) {
    // Only real user edits make the slug "dirty" (no longer auto-derived
    // from name). Programmatic dispatches from nameChanged have
    // `isTrusted === false` and should keep the sync loop alive.
    if (event?.isTrusted) {
      this.slugDirty = this.slugInputTarget.value.trim().length > 0
    }
    this.#scheduleCheck()
  }

  #scheduleCheck() {
    if (this.checkTimer) clearTimeout(this.checkTimer)
    this.#setStatus("checking")
    this.checkTimer = setTimeout(() => this.#runCheck(), this.debounceValue)
  }

  async #runCheck() {
    const slug = this.slugInputTarget.value.trim()
    const name = this.nameInputTarget.value.trim()

    if (!slug && !name) {
      this.#setStatus("blank")
      this.#setSubmitEnabled(false)
      return
    }

    if (this.abortController) this.abortController.abort()
    this.abortController = new AbortController()

    try {
      const response = await fetch(this.checkUrlValue, {
        method: "POST",
        credentials: "same-origin",
        signal: this.abortController.signal,
        headers: {
          "Content-Type":     "application/json",
          "Accept":           "application/json",
          "X-CSRF-Token":     this.#csrfToken()
        },
        body: JSON.stringify({ slug, name })
      })

      if (!response.ok) throw new Error(`slug-check ${response.status}`)

      const data = await response.json()
      this.#setStatus(data.ok ? "available" : (data.reason || "taken"))
      this.#setSubmitEnabled(Boolean(data.ok))
    } catch (error) {
      if (error.name === "AbortError") return
      this.#setStatus("blank")
    }
  }

  #setStatus(key) {
    const status = this.statusTarget
    const label  = this.statusLabelsValue[key] || ""
    status.textContent = ""

    const dot = document.createElement("span")
    dot.className = "w-1.5 h-1.5 rounded-full shrink-0"
    const text = document.createElement("span")
    text.textContent = label

    switch (key) {
      case "available":
        dot.classList.add("bg-accent")
        status.className = "inline-flex items-center gap-1.5 text-[12px] font-medium text-accent"
        break
      case "checking":
        dot.classList.add("bg-muted", "animate-pulse")
        status.className = "inline-flex items-center gap-1.5 text-[12px] font-medium text-muted"
        break
      case "taken":
      case "reserved":
      case "format":
      case "length":
        dot.classList.add("bg-err")
        status.className = "inline-flex items-center gap-1.5 text-[12px] font-medium text-err"
        break
      default:
        status.className = "inline-flex items-center gap-1.5 text-[12px] font-medium text-muted"
    }

    status.appendChild(dot)
    status.appendChild(text)
  }

  #setSubmitEnabled(enabled) {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = !enabled
  }

  #csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }

  // Mirror String#parameterize well enough for the preview — the server
  // re-normalizes via Account.slugify so the authoritative value comes
  // back from the availability check.
  #slugify(value) {
    return value
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
  }
}
