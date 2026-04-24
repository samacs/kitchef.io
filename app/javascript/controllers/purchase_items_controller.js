import { Controller } from "@hotwired/stimulus"

// Dynamic line-item editor for the new/edit purchase form.
//
// Markup contract:
//   <div data-controller="purchase-items"
//        data-purchase-items-template-value="<%= escape_javascript(render 'item_row_template') %>">
//     <ul data-purchase-items-target="list">
//       <%= render "item_row", i: 0 %>
//     </ul>
//     <button data-action="click->purchase-items#add">Agregar línea</button>
//     <div data-purchase-items-target="runningTotal"></div>
//   </div>
//
// Each item row has:
//   • ingredient combobox (hidden input name="purchase[items_attributes][<i>][ingredient_id]")
//   • quantity input (…[quantity])
//   • unit select (…[unit])
//   • unit_cost input (…[unit_cost])
//   • hidden _destroy marker for Rails nested attributes
//
// The controller:
//   - Appends a fresh, empty row when the user hits "Agregar línea". Index
//     is the count of existing visible rows.
//   - On "Quitar", hides the row and flips its `_destroy` hidden input
//     to "1" so existing items can be removed on update without
//     disappearing from the DOM mid-submit.
//   - Recomputes the running total whenever any quantity or unit_cost
//     input fires `input` / `change`. Total = Σ (qty × cost_cents).
export default class extends Controller {
  static targets = ["list", "runningTotal", "row", "overrideInput"]
  static values = {
    template: String,
    currencySymbol: { type: String, default: "$" }
  }

  connect() {
    this.onInput = this.recomputeTotal.bind(this)
    this.element.addEventListener("input", this.onInput)
    this.element.addEventListener("change", this.onInput)
    this.recomputeTotal()
  }

  disconnect() {
    this.element.removeEventListener("input", this.onInput)
    this.element.removeEventListener("change", this.onInput)
  }

  add(event) {
    event.preventDefault()
    const nextIndex = this.listTarget.querySelectorAll("[data-purchase-items-target=row]").length +
      this.listTarget.querySelectorAll("[data-row-removed]").length
    const html = this.templateValue.replace(/__INDEX__/g, String(nextIndex))
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.recomputeTotal()

    // Focus the first input in the new row so the thumb doesn't have to
    // scroll back up to tap a field.
    const newRows = this.listTarget.querySelectorAll("[data-purchase-items-target=row]")
    const last = newRows[newRows.length - 1]
    const firstInput = last?.querySelector("input, select, [role=combobox]")
    firstInput?.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-purchase-items-target=row]")
    if (!row) return
    const destroyInput = row.querySelector("input[name$='[_destroy]']")
    if (destroyInput) {
      destroyInput.value = "1"
      row.hidden = true
      row.dataset.rowRemoved = ""
      row.removeAttribute("data-purchase-items-target")
    } else {
      row.remove()
    }
    this.recomputeTotal()
  }

  recomputeTotal() {
    let totalCents = 0
    this.rowTargets.forEach(row => {
      const qty = parseFloat(row.querySelector("[data-role=quantity]")?.value || "0")
      const costStr = row.querySelector("[data-role=unit-cost]")?.value || "0"
      const costCents = Math.round(parseFloat(costStr.replace(",", "")) * 100) || 0
      if (!isNaN(qty) && qty > 0 && costCents > 0) {
        totalCents += Math.round(qty * costCents)
      }
    })

    if (this.hasRunningTotalTarget) {
      this.runningTotalTarget.textContent = this.#formatMxn(totalCents)
    }
    // Let external listeners (e.g. an override validator) react.
    this.element.dispatchEvent(new CustomEvent("purchase-items:recomputed", {
      bubbles: true,
      detail: { totalCents }
    }))
  }

  #formatMxn(cents) {
    const pesos = (cents / 100).toLocaleString("es-MX", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
    return `${this.currencySymbolValue}${pesos}`
  }
}
