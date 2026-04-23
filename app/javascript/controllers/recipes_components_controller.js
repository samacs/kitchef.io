import { Controller } from "@hotwired/stimulus"

// Decomposition-form behavior for /recipes/:id/edit. Owns:
//   • "+ agregar componente" — clones the <template> blueprint, fills
//     hidden fields (componentable_type/id/unit), appends to the rows
//     list, and dispatches a `change` so the form's autosave layer
//     triggers a save + cost-summary refresh.
//   • "×" on a row — sets `_destroy=1` and hides the row. Autosave then
//     commits the destroy and the server swaps the cost summary.
//   • Unit-dropdown constraint — filters each row's unit options to
//     units in the same measurement family as the componentable's
//     canonical unit (see UnitConverter.FAMILIES).
//
// The server is the source of truth for the cost total and margin chip;
// this controller never does math. It just mutates form state and lets
// the autosave + server-side calculator do the work.
const FAMILIES = {
  g:       { family: "mass",   label: "g" },
  kg:      { family: "mass",   label: "kg" },
  ml:      { family: "volume", label: "ml" },
  l:       { family: "volume", label: "l" },
  piece:   { family: "count",  label: "pieza" },
  serving: { family: "count",  label: "porción" }
}

export default class extends Controller {
  static targets = ["blueprint", "row", "destroyFlag"]

  connect() {
    this.nextIndex = this.element.querySelectorAll("[data-recipes-components-target='row']").length + 100
  }

  add(event) {
    event.preventDefault()
    const btn = event.currentTarget

    const type = btn.dataset.componentableType
    const id   = btn.dataset.componentableId
    const name = btn.dataset.componentableName
    const unit = btn.dataset.componentableUnit

    const fragment = this.blueprintTarget.content.cloneNode(true)
    const row = fragment.querySelector("[data-recipes-components-target='row']")
    if (!row) return

    const index = this.nextIndex++
    row.querySelectorAll("input, select").forEach((el) => {
      if (el.name) el.name = el.name.replace("NEW_RECORD", index)
    })
    row.querySelector("[data-field='componentable_type']").value = type
    row.querySelector("[data-field='componentable_id']").value   = id
    row.querySelector("[data-field='name']").textContent         = name

    const unitSelect = row.querySelector("[data-field='unit']")
    this.populateUnitSelect(unitSelect, unit)

    // Insert above the <details> picker so the new row lines up with
    // any existing ones. We accept two cases:
    //   1. An existing <ol> of rows — append to it.
    //   2. Empty-state paragraph — swap the whole block for a fresh <ol>.
    const list = this.element.querySelector("ol") || this.ensureList()
    list.appendChild(row)

    // Close the picker after adding for a calmer UX.
    const details = this.element.querySelector("details")
    if (details) details.open = false

    this.dispatchChange(list)
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-recipes-components-target='row']")
    if (!row) return

    const flag = row.querySelector("[data-recipes-components-target='destroyFlag']")
    if (flag) flag.value = "1"

    row.classList.add("hidden")
    this.dispatchChange(row)
  }

  ensureList() {
    const existing = this.element.querySelector("ol")
    if (existing) return existing

    const ol = document.createElement("ol")
    ol.className = "flex flex-col divide-y divide-line rounded-card-sm bg-surface border border-line"
    const emptyMsg = this.element.querySelector("p")
    if (emptyMsg) emptyMsg.replaceWith(ol)
    else this.element.insertBefore(ol, this.element.querySelector("details"))
    return ol
  }

  populateUnitSelect(select, baseUnit) {
    if (!select) return
    const family = FAMILIES[baseUnit]?.family
    const units = family
      ? Object.entries(FAMILIES).filter(([_, meta]) => meta.family === family).map(([u]) => u)
      : [baseUnit]

    select.innerHTML = ""
    units.forEach((u) => {
      const opt = document.createElement("option")
      opt.value = u
      opt.textContent = FAMILIES[u]?.label || u
      if (u === baseUnit) opt.selected = true
      select.appendChild(opt)
    })
  }

  dispatchChange(node) {
    // Fires on the node itself AND bubbles up through the form so the
    // form-autosave controller's listener picks it up. Without this
    // the hidden-field mutations don't generate a change event.
    const evt = new Event("change", { bubbles: true })
    node.dispatchEvent(evt)
  }
}
