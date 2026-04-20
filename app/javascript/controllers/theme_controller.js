import { Controller } from "@hotwired/stimulus"

// Handles the three-state theme toggle: auto → light → dark → auto.
// The pre-paint initial class is set by app/javascript/theme_bootstrap.js.
//
// Markup contract (all translated strings come from the server — no copy
// lives in this controller):
//
//   <button data-controller="theme"
//           data-action="theme#cycle"
//           data-theme-storage-key-value="kitchef_theme"
//           data-theme-auto-label-value="<%= t('theme.auto') %>"
//           data-theme-light-label-value="<%= t('theme.light') %>"
//           data-theme-dark-label-value="<%= t('theme.dark') %>"
//           data-theme-target="button">
//     <span data-theme-target="label"></span>
//   </button>
//
// The button's [data-theme-mode] attribute reflects the current mode
// (auto | light | dark) so CSS can swap icon / affordance per state.
export default class extends Controller {
  // `option` targets are the three segmented-control buttons in the
  // user-menu theme row (Auto / Claro / Oscuro). Each carries a
  // `data-mode="auto|light|dark"` attribute; the active option gets a
  // `[data-active]` attribute which the CSS uses to raise its surface.
  static targets = ["button", "label", "option"]

  static values = {
    storageKey: { type: String, default: "kitchef_theme" },
    autoLabel:  { type: String, default: "" },
    lightLabel: { type: String, default: "" },
    darkLabel:  { type: String, default: "" }
  }

  connect() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.systemListener = () => this.#applyCurrent()
    this.mediaQuery.addEventListener("change", this.systemListener)

    this.storageListener = (event) => {
      if (event.key === this.storageKeyValue) this.#applyCurrent()
    }
    window.addEventListener("storage", this.storageListener)

    this.#applyCurrent()
  }

  disconnect() {
    this.mediaQuery?.removeEventListener("change", this.systemListener)
    window.removeEventListener("storage", this.storageListener)
  }

  cycle() {
    const order = ["auto", "light", "dark"]
    const next = order[(order.indexOf(this.#currentMode()) + 1) % order.length]
    this.#store(next)
    this.#applyCurrent()
  }

  // Direct-select action for the segmented control inside the user menu.
  // Each option carries `data-theme-mode-param="auto|light|dark"` which
  // Stimulus exposes as event.params.mode.
  set(event) {
    const mode = event?.params?.mode
    if (!["auto", "light", "dark"].includes(mode)) return
    this.#store(mode)
    this.#applyCurrent()
  }

  #currentMode() {
    try {
      return localStorage.getItem(this.storageKeyValue) || "auto"
    } catch (_e) {
      return "auto"
    }
  }

  #store(mode) {
    try {
      localStorage.setItem(this.storageKeyValue, mode)
    } catch (_e) {
      // Silently accept — toggle still works for the current tab.
    }
  }

  #labelFor(mode) {
    switch (mode) {
      case "light": return this.lightLabelValue
      case "dark":  return this.darkLabelValue
      default:      return this.autoLabelValue
    }
  }

  #applyCurrent() {
    const mode = this.#currentMode()
    const systemDark = this.mediaQuery.matches
    const isDark = mode === "dark" || (mode === "auto" && systemDark)
    document.documentElement.classList.toggle("dark", isDark)

    const label = this.#labelFor(mode)

    if (this.hasButtonTarget) {
      this.buttonTarget.dataset.themeMode = mode
      if (label) this.buttonTarget.setAttribute("aria-label", label)
    }

    if (this.hasLabelTarget && label) {
      this.labelTarget.textContent = label
    }

    // Mark the active option in the segmented control so CSS can raise
    // its surface — no-op when this controller doesn't wrap a segmented
    // control (e.g., the icon-button variant has only button/label).
    if (this.hasOptionTarget) {
      for (const option of this.optionTargets) {
        const active = option.dataset.mode === mode
        if (active) option.setAttribute("data-active", "")
        else option.removeAttribute("data-active")
        // Segmented options inside a menu are role="menuitemradio"; set
        // aria-checked. Fall back to aria-pressed when the option is a
        // standalone button outside a menu context.
        if (option.getAttribute("role") === "menuitemradio") {
          option.setAttribute("aria-checked", String(active))
        } else {
          option.setAttribute("aria-pressed", String(active))
        }
      }
    }
  }
}
