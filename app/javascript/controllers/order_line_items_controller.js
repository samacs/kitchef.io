import { Controller } from "@hotwired/stimulus"

// Manages the line-items editor inside the order form:
//   - `add` clones the <template> markup and inserts a new row, replacing
//     the placeholder index "NEW_RECORD" with a unique timestamp so
//     accepts_nested_attributes can keep submissions distinct.
//   - `remove` either flips _destroy=1 on persisted rows (so the server
//     deletes them) or removes the DOM node for unsaved rows.
//   - `recipeChanged` auto-fills the unit_price input with the recipe's
//     current sale_price_cents (the "data-price-cents" data attribute on
//     each <option>), but only if the operator hasn't manually entered a
//     price for the row already.
//   - `recalc` recomputes the per-line subtotal and the order total —
//     pure display, server is the source of truth.
export default class extends Controller {
  static targets = [
    "rows", "template", "row", "recipeSelect", "quantity", "price",
    "lineTotal", "destroy", "total", "empty"
  ]

  static values = {
    recipeOptions: { type: Array, default: [] }
  }

  connect() {
    this.recalc()
    this.refreshEmptyState()
  }

  add(event) {
    event.preventDefault()
    // Rails strong_parameters only accepts hash-of-records under
    // `accepts_nested_attributes_for` when the outer keys look like
    // integer indices. String prefixes like "new_…" are silently
    // filtered out, which produced an `items_attributes => {}` and a
    // failing "can't be blank" on submit.
    const index = Date.now()
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", index)
    const wrapper = document.createElement("div")
    wrapper.innerHTML = html.trim()
    const node = wrapper.firstElementChild
    this.rowsTarget.appendChild(node)
    this.refreshEmptyState()
    this.recalc()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-order-line-items-target='row']")
    if (!row) return

    const destroy = row.querySelector("[data-order-line-items-target='destroy']")
    const id = row.querySelector("input[name$='[id]']")

    if (id && destroy) {
      destroy.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }
    this.refreshEmptyState()
    this.recalc()
  }

  recipeChanged(event) {
    const select = event.target
    const row = select.closest("[data-order-line-items-target='row']")
    if (!row) return

    const priceInput = this.priceInput(row)
    if (!priceInput) return

    if (priceInput.value && Number(priceInput.value) > 0) {
      this.recalc()
      return
    }

    const opt = select.options[select.selectedIndex]
    const cents = parseInt(opt?.dataset?.priceCents || "0", 10)
    if (cents > 0) priceInput.value = (cents / 100).toFixed(2)
    this.recalc()
  }

  recalc() {
    const visibleRows = this.rowTargets.filter(row => !row.classList.contains("hidden"))
    let total = 0
    visibleRows.forEach((row) => {
      const qty = parseFloat(row.querySelector("input[name$='[quantity]']")?.value || "0") || 0
      const pesos = parseFloat(this.priceInput(row)?.value || "0") || 0
      const priceCents = Math.round(pesos * 100)
      const lineCents = Math.round(qty * priceCents)
      total += lineCents
      const lineTotal = row.querySelector("[data-order-line-items-target='lineTotal']")
      if (lineTotal) lineTotal.textContent = this.format(lineCents)
    })

    if (this.hasTotalTarget) this.totalTarget.textContent = this.format(total)
  }

  priceInput(row) {
    return row.querySelector("input[name$='[unit_price]']") ||
           row.querySelector("input[name$='[unit_price_cents]']")
  }

  refreshEmptyState() {
    if (!this.hasEmptyTarget) return
    const visibleRows = this.rowTargets.filter(row => !row.classList.contains("hidden"))
    this.emptyTarget.classList.toggle("hidden", visibleRows.length > 0)
  }

  format(cents) {
    const pesos = (cents / 100).toFixed(2)
    const [whole, fraction] = pesos.split(".")
    const withSeparators = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return `$${withSeparators}.${fraction}`
  }
}
