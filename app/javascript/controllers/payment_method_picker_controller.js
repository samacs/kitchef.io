import { Controller } from "@hotwired/stimulus"

// Reveals method-specific detail panels based on the selected radio.
// Listens for `storefront-cart:totals` so the cash-change calculation
// always reflects the live total (subtotal + tip).
export default class extends Controller {
  static targets = ["radio", "detail", "cashAmountInput", "changeDisplay"]

  connect() {
    this.totalCents = 0
    document.addEventListener("storefront-cart:totals", this.onCartTotals)
    this.#showActiveDetail()
    document.dispatchEvent(new CustomEvent("storefront-cart:request-totals"))
  }

  disconnect() {
    document.removeEventListener("storefront-cart:totals", this.onCartTotals)
  }

  onCartTotals = (event) => {
    this.totalCents = parseInt(event.detail?.totalCents ?? 0, 10) || 0
    this.#refreshChangeDisplay()
  }

  select() {
    this.#showActiveDetail()
    this.#refreshChangeDisplay()
  }

  updateCashAmount() {
    this.#refreshChangeDisplay()
  }

  // ── Internals ──────────────────────────────────────────────────────────

  #refreshChangeDisplay() {
    if (!this.hasCashAmountInputTarget || !this.hasChangeDisplayTarget) return

    const target = this.changeDisplayTarget
    const wrap = target.closest("[data-change-wrap]")
    const raw = this.cashAmountInputTarget.value.replace(",", ".")
    const pesosPaid = parseFloat(raw)
    const totalPesos = this.totalCents / 100

    if (!Number.isFinite(pesosPaid) || pesosPaid <= 0 || totalPesos <= 0) {
      wrap?.classList.add("hidden")
      return
    }

    wrap?.classList.remove("hidden")

    // Round both sides to cents before comparing so floating-point
    // drift never makes `< total` evaluate true at the boundary.
    const paidCents  = Math.round(pesosPaid * 100)
    const totalCents = Math.round(totalPesos * 100)

    if (paidCents < totalCents) {
      const shortCents = totalCents - paidCents
      target.dataset.kind = "short"
      const prefix = target.dataset.changePrefixShort || ""
      target.textContent = `${prefix} ${this.#formatPesos(shortCents)}`.trim()
    } else {
      const changeCents = paidCents - totalCents
      target.dataset.kind = "change"
      const prefix = target.dataset.changePrefixChange || ""
      target.textContent = `${prefix} ${this.#formatPesos(changeCents)}`.trim()
    }
  }

  #formatPesos(cents) {
    const pesos = (cents / 100).toLocaleString("es-MX", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    return `$${pesos}`
  }

  #showActiveDetail() {
    const selected = this.radioTargets.find(r => r.checked)
    this.detailTargets.forEach(d => {
      d.classList.toggle("hidden", d.dataset.method !== selected?.value)
    })
  }
}
