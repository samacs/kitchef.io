import { Controller } from "@hotwired/stimulus"

// Decomposition-form behavior for /recipes/:id/edit. Owns:
//   • "+ agregar componente" — clones the <template> blueprint, fills
//     hidden fields (componentable_type/id/unit), appends to the rows
//     list, and dispatches a `change` so the form's autosave layer
//     triggers a save. After the autosave round-trips, the controller
//     swaps in fresh server-rendered rows that carry the persisted IDs.
//   • "×" on a row — sets `_destroy=1` and hides the row. Autosave then
//     commits the destroy and the server returns rows with the row gone.
//   • Unit-dropdown constraint — filters each row's unit options to
//     units in the same measurement family as the componentable's
//     canonical unit (see UnitConverter.FAMILIES).
//   • Duplicate prevention — clicking the same ingredient/recipe in the
//     picker increments the existing row's quantity instead of inserting
//     a second row. Operators only ever want one row per ingredient.
//
// The server is the source of truth for the cost total, margin chip,
// AND the rows list. This controller never does math. It mutates form
// state and lets the server-side calculator + replace do the work.
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

  // ── Index allocation ─────────────────────────────────────────────────
  // Server-rendered rows use indices 0..N from the loop. Client-side
  // adds use a monotonically-increasing counter prefixed past the
  // server space so they never collide. The counter persists across
  // turbo-stream replaces because the controller's element doesn't
  // disconnect when only the inner rows are swapped.
  connect() {
    this.nextIndex = 1_000_000 + Math.floor(Math.random() * 1_000_000)
  }

  // ── Adding ───────────────────────────────────────────────────────────

  add(event) {
    event.preventDefault()
    const btn = event.currentTarget

    const type = btn.dataset.componentableType
    const id   = btn.dataset.componentableId
    const name = btn.dataset.componentableName
    const unit = btn.dataset.componentableUnit

    // Dedupe: if a row already exists for this componentable_type+id and
    // is not flagged for destroy, increment its quantity rather than
    // inserting a second row. Two rows for the same ingredient is almost
    // never what the operator wants, and the cost engine would just sum
    // them anyway.
    const existing = this.#findActiveRowFor(type, id)
    if (existing) {
      const qtyInput = existing.querySelector("input[name$='[quantity]']")
      if (qtyInput) {
        const current = parseFloat(qtyInput.value) || 0
        qtyInput.value = (current + 1).toString()
        qtyInput.focus()
        qtyInput.select()
      }
      this.#closePicker()
      this.dispatchChange(qtyInput || existing)
      return
    }

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

    // Stable DOM id so Idiomorph can match the client-added row with
    // the server-rendered row after autosave — prevents duplication.
    row.id = `component_${type.toLowerCase()}_${id}`
    row.dataset.componentableType = type
    row.dataset.componentableId   = id

    const unitSelect = row.querySelector("[data-field='unit']")
    this.populateUnitSelect(unitSelect, unit)

    // Insert above the <details> picker so the new row lines up with
    // any existing ones. We accept two cases:
    //   1. An existing <ol> of rows — append to it.
    //   2. Empty-state paragraph — swap the whole block for a fresh <ol>.
    const list = this.element.querySelector("ol") || this.ensureList()
    list.appendChild(row)

    this.#closePicker()
    this.dispatchChange(list)
  }

  // ── Removing ─────────────────────────────────────────────────────────

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-recipes-components-target='row']")
    if (!row) return

    const flag = row.querySelector("[data-recipes-components-target='destroyFlag']")
    if (flag) flag.value = "1"

    row.classList.add("hidden")
    this.dispatchChange(row)
  }

  // ── Byproduct toggle ──────────────────────────────────────────────────

  toggleByproduct(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-recipes-components-target='row']")
    if (!row) return

    const field = row.querySelector("[data-field='is_byproduct']")
    if (!field) return

    const current = field.value === "1"
    const next = !current
    field.value = next ? "1" : "0"

    row.classList.toggle("bg-accent-soft/30", next)

    const costEl = row.querySelector(".tabular-nums")
    if (costEl) {
      costEl.classList.toggle("text-accent", next)
      costEl.classList.toggle("line-through", next)
      costEl.classList.toggle("text-ink-2", !next)
    }

    const btn = event.currentTarget
    btn.textContent = next ? "Es subproducto" : "Marcar como subproducto"
    btn.classList.toggle("text-accent", next)
    btn.classList.toggle("text-muted", !next)

    const badge = row.querySelector("[data-byproduct-badge]")
    if (badge) {
      badge.hidden = !next
    } else if (next) {
      const nameDiv = row.querySelector(".flex-1 .flex")
      if (nameDiv) {
        const span = document.createElement("span")
        span.dataset.byproductBadge = "true"
        span.className = "inline-flex items-center gap-1 rounded-full bg-accent-soft px-1.5 py-0.5 text-[10px] font-medium text-accent"
        span.textContent = "subproducto"
        nameDiv.appendChild(span)
      }
    }

    this.dispatchImmediate()
  }

  dispatchImmediate() {
    this.element.dispatchEvent(new CustomEvent("form-autosave:immediate", { bubbles: true }))
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  #findActiveRowFor(type, id) {
    return this.rowTargets.find((row) => {
      if (row.classList.contains("hidden")) return false
      const flag = row.querySelector("[data-recipes-components-target='destroyFlag']")
      if (flag && flag.value === "1") return false
      return row.dataset.componentableType === type &&
             row.dataset.componentableId   === String(id)
    })
  }

  #closePicker() {
    const details = this.element.querySelector("details")
    if (details) details.open = false
  }

  ensureList() {
    const existing = this.element.querySelector("ol")
    if (existing) return existing

    const ol = document.createElement("ol")
    ol.className = "flex flex-col divide-y divide-line rounded-card-sm bg-surface border border-line"
    const emptyMsg = this.element.querySelector("#recipe_components_rows p")
    if (emptyMsg) emptyMsg.replaceWith(ol)
    else {
      const wrapper = this.element.querySelector("#recipe_components_rows") || this.element
      wrapper.appendChild(ol)
    }
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
