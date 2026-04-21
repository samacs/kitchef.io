import { Controller } from "@hotwired/stimulus"

/*
 * Customer-facing theme cycler on the storefront. Keys localStorage
 * per-slug so a customer's preference on Elena's storefront doesn't
 * leak to Mario's. Pre-paint boot happens inline in
 * `layouts/storefront.html.erb` to avoid FOUC; this controller handles
 * the *click* and keeps the toggle's icon in sync with the active mode.
 *
 * A `toggle` target (the button) gets a `data-theme-mode` attribute
 * set to "auto" | "light" | "dark". The storefront CSS shows only the
 * matching `<svg class="kc-sf-glyph" data-mode="…">` glyph so the icon
 * always reflects the current mode.
 */
export default class extends Controller {
  static targets = ["toggle"]
  static values = {
    slug: String
  }

  connect() {
    const mode = this.currentMode()
    this.apply(mode)
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.systemListener = () => {
      // Only re-apply when the user has the `auto` preference; a
      // forced `light`/`dark` should survive a system change.
      if (this.currentMode() === "auto") this.apply("auto")
    }
    this.mediaQuery.addEventListener("change", this.systemListener)
  }

  disconnect() {
    if (this.mediaQuery && this.systemListener) {
      this.mediaQuery.removeEventListener("change", this.systemListener)
    }
  }

  cycle(event) {
    if (event) event.preventDefault()
    const order = [ "auto", "light", "dark" ]
    const current = this.currentMode()
    const next = order[(order.indexOf(current) + 1) % order.length]
    this.persist(next)
    this.apply(next)
  }

  currentMode() {
    return localStorage.getItem(this.storageKey) || "auto"
  }

  get storageKey() {
    return `kitchef_sf_theme_${this.slugValue}`
  }

  persist(mode) {
    try {
      localStorage.setItem(this.storageKey, mode)
    } catch {
      /* quota exceeded — ignore */
    }
  }

  apply(mode) {
    const sys = window.matchMedia("(prefers-color-scheme: dark)").matches
    const dark = mode === "dark" || (mode === "auto" && sys)
    document.documentElement.classList.toggle("dark", dark)
    document.documentElement.dataset.themeMode = mode
    if (this.hasToggleTarget) {
      this.toggleTarget.dataset.themeMode = mode
    }
  }
}
