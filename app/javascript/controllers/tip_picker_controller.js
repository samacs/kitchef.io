import { Controller } from "@hotwired/stimulus"

// Coordinates with `storefront-cart` via document-level events:
//   - Listens for `storefront-cart:totals` to refresh percentage amounts
//     and re-emit the current tip whenever the cart subtotal changes.
//   - Dispatches `tip-picker:changed` whenever the customer picks a
//     different chip, types in a custom amount, or the underlying tip
//     value changes due to a subtotal update.
//
// Money is in CENTS everywhere. Pesos only appear at the input boundary
// (the "Otro" custom field accepts pesos and converts to cents).
export default class extends Controller {
  static targets = ["preset", "customWrap", "customInput", "hiddenField", "presetAmount"]

  connect() {
    this.subtotalCents = 0
    this.selectedPct   = 0       // 0 means "Sin propina" preset
    this.isCustom      = false
    this.customCents   = 0
    this.hiddenFieldTarget.value = "0"

    document.addEventListener("storefront-cart:totals", this.onCartTotals)
    this.#syncUI()
    this.#emit()
    // Pull current totals — the cart controller may have already
    // broadcast before we mounted.
    document.dispatchEvent(new CustomEvent("storefront-cart:request-totals"))
  }

  disconnect() {
    document.removeEventListener("storefront-cart:totals", this.onCartTotals)
  }

  onCartTotals = (event) => {
    const subtotal = parseInt(event.detail?.subtotalCents ?? 0, 10) || 0
    if (subtotal === this.subtotalCents) return
    this.subtotalCents = subtotal
    this.#refreshPresetLabels()
    if (!this.isCustom) {
      this.#writeHidden(this.#tipForPct(this.selectedPct))
      this.#emit()
    }
  }

  selectPreset(event) {
    const pct = parseInt(event.currentTarget.dataset.pct, 10)
    this.selectedPct = pct
    this.isCustom = false
    this.customCents = 0
    this.customWrapTarget.classList.add("hidden")
    this.customInputTarget.value = ""
    this.#writeHidden(this.#tipForPct(pct))
    this.#syncUI()
    this.#emit()
  }

  selectCustom() {
    this.selectedPct = -1
    this.isCustom = true
    this.customWrapTarget.classList.remove("hidden")
    this.customInputTarget.focus()
    this.#writeHidden(this.customCents)
    this.#syncUI()
    this.#emit()
  }

  updateCustom() {
    const raw = this.customInputTarget.value.replace(",", ".")
    const pesos = parseFloat(raw)
    const cents = Number.isFinite(pesos) ? Math.round(Math.max(0, pesos) * 100) : 0
    this.customCents = cents
    this.#writeHidden(cents)
    this.#emit()
  }

  // ── Internals ──────────────────────────────────────────────────────────

  #tipForPct(pct) {
    if (!pct || pct <= 0) return 0
    return Math.round(this.subtotalCents * pct / 100)
  }

  #writeHidden(cents) {
    this.hiddenFieldTarget.value = String(cents | 0)
  }

  #refreshPresetLabels() {
    this.presetAmountTargets.forEach(el => {
      const pct = parseInt(el.dataset.pct, 10)
      const cents = this.#tipForPct(pct)
      el.textContent = cents > 0 ? this.#formatPesos(cents) : ""
    })
  }

  #syncUI() {
    this.presetTargets.forEach(btn => {
      const pct = parseInt(btn.dataset.pct, 10)
      const active = !this.isCustom && pct === this.selectedPct
      btn.dataset.active = active.toString()
      btn.querySelectorAll("[data-active]").forEach(child => {
        child.dataset.active = active.toString()
      })
    })
    // The custom chip lives outside the preset target list so we can
    // toggle its active state independently — it's never confused with
    // a percentage chip.
    const customChip = this.element.querySelector("[data-tip-picker-custom-chip]")
    if (customChip) {
      customChip.dataset.active = this.isCustom.toString()
      customChip.querySelectorAll("[data-active]").forEach(child => {
        child.dataset.active = this.isCustom.toString()
      })
    }
  }

  #emit() {
    document.dispatchEvent(new CustomEvent("tip-picker:changed", {
      detail: { tipCents: parseInt(this.hiddenFieldTarget.value, 10) || 0 }
    }))
  }

  #formatPesos(cents) {
    return `$${(cents / 100).toLocaleString("es-MX", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
  }
}
