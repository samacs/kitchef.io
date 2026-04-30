import { Controller } from "@hotwired/stimulus"

// Searchable select with inline create affordance. Pairs with
// Ui::ComboboxComponent. See that component's Ruby file for the full UX
// contract.
//
// Markup contract (what the sidecar ERB renders):
//   data-controller="combobox"
//   data-combobox-create-value='{"path": "...", "params": {"kind": "ingredient"}}'
//   data-combobox-csrf-value="..."
//
//   targets:
//     search      — visible text input the user types into
//     value       — hidden input that carries the id (form payload)
//     list        — <ul> popover
//     item        — one <li role="option"> per static option
//     empty       — <li> shown when filter matches nothing AND create disabled
//     create      — <li> shown when filter matches nothing AND create enabled
//     createLabel — the span inside `create` we rewrite ("Agregar «term»")
//     toggle      — chevron button
//     options     — the <datalist> element holding static options
//                   (appended-to by turbo streams when categories#create runs)
//
// Keyboard shortcuts and mouse handlers deliberately use `mousedown`
// instead of `click` for option selection so the blur-on-pointerdown
// doesn't fire the combobox's built-in close handler before the choice
// registers.
export default class extends Controller {
  static targets = ["search", "value", "list", "item", "empty", "create",
                    "createLabel", "toggle", "options"]
  static values = {
    create: { type: Object, default: {} },
    csrf:   String
  }

  connect() {
    this.isOpen = false
    this.highlightIndex = -1
    this.onOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    document.addEventListener("mousedown", this.onOutsideClick)

    this.#syncItemsFromOptions()

    // Turbo Stream can append <option> nodes to the <datalist> — watch
    // that list and rebuild our visible <li> rows whenever it changes.
    if (this.hasOptionsTarget) {
      this.optionsObserver = new MutationObserver(() => this.#syncItemsFromOptions())
      this.optionsObserver.observe(this.optionsTarget, { childList: true })
    }

    this.#renderCreateRow()
  }

  disconnect() {
    document.removeEventListener("mousedown", this.onOutsideClick)
    this.optionsObserver?.disconnect()
  }

  // ---- Actions ---------------------------------------------------------

  open() {
    if (this.isOpen) return
    this.isOpen = true
    this.listTarget.hidden = false
    this.searchTarget.setAttribute("aria-expanded", "true")
    this.highlightIndex = -1
    this.#renderFilter()
  }

  close() {
    if (!this.isOpen) return
    this.isOpen = false
    this.listTarget.hidden = true
    this.searchTarget.setAttribute("aria-expanded", "false")
    this.highlightIndex = -1
    this.#unhighlightAll()
    this.#restoreSearchValueToSelection()
  }

  toggle(event) {
    event.preventDefault()
    this.isOpen ? this.close() : this.open()
    if (this.isOpen) this.searchTarget.focus()
  }

  filter() {
    if (!this.isOpen) this.open()
    this.#renderFilter()
  }

  keydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.open()
        this.#moveHighlight(+1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.#moveHighlight(-1)
        break
      case "Enter":
        event.preventDefault()
        this.#commitHighlighted()
        break
      case "Escape":
        event.preventDefault()
        this.close()
        break
      case "Tab":
        this.close()
        break
    }
  }

  pickEvent(event) {
    event.preventDefault()
    const li = event.currentTarget
    this.#select(li.dataset.value, li.dataset.label)
    this.close()
  }

  createEvent(event) {
    event.preventDefault()
    this.#createFromSearchTerm()
  }

  // ---- Internals -------------------------------------------------------

  #normalize(str) {
    return str.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
  }

  #renderFilter() {
    const query = this.#normalize(this.searchTarget.value.trim())
    let visible = 0
    let exact = false

    this.itemTargets.forEach(li => {
      const label = this.#normalize(li.dataset.label || "")
      const match = query === "" || label.includes(query)
      li.hidden = !match
      if (match) visible += 1
      if (label === query && query !== "") exact = true
    })

    const hasCreate = this.#createEnabled() && query !== "" && !exact
    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = visible > 0 || hasCreate
    }
    if (this.hasCreateTarget) {
      this.createTarget.hidden = !hasCreate
      if (hasCreate && this.hasCreateLabelTarget) {
        // "Agregar «Mariscos»"
        this.createLabelTarget.textContent = this.#createLabelText(query)
      }
    }

    // Reset highlight — first visible option gets it.
    this.highlightIndex = -1
    this.#unhighlightAll()
    const firstVisible = this.#visibleRows()[0]
    if (firstVisible) {
      firstVisible.setAttribute("data-highlighted", "")
      this.highlightIndex = 0
      this.searchTarget.setAttribute(
        "aria-activedescendant",
        firstVisible.id || ""
      )
    } else {
      this.searchTarget.removeAttribute("aria-activedescendant")
    }
  }

  #moveHighlight(step) {
    const rows = this.#visibleRows()
    if (rows.length === 0) return

    this.highlightIndex = Math.max(0, Math.min(
      rows.length - 1,
      this.highlightIndex + step
    ))

    this.#unhighlightAll()
    const active = rows[this.highlightIndex]
    active.setAttribute("data-highlighted", "")
    active.scrollIntoView({ block: "nearest" })
    if (active.id) this.searchTarget.setAttribute("aria-activedescendant", active.id)
  }

  #commitHighlighted() {
    const rows = this.#visibleRows()
    const active = rows[this.highlightIndex] || rows[0]
    if (!active) {
      // Nothing highlighted — try to create if enabled.
      if (this.#createEnabled() && this.searchTarget.value.trim()) {
        this.#createFromSearchTerm()
      }
      return
    }

    if (active === this.createTarget) {
      this.#createFromSearchTerm()
      return
    }

    this.#select(active.dataset.value, active.dataset.label)
    this.close()
  }

  #select(id, label) {
    this.valueTarget.value = id
    this.searchTarget.value = label
    this.itemTargets.forEach(li => {
      li.setAttribute("aria-selected", li.dataset.value === id ? "true" : "false")
    })
    this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.element.dispatchEvent(new CustomEvent("combobox:selected", {
      bubbles: true,
      detail: { id, label }
    }))
  }

  #unhighlightAll() {
    this.itemTargets.forEach(li => li.removeAttribute("data-highlighted"))
    if (this.hasCreateTarget) this.createTarget.removeAttribute("data-highlighted")
  }

  #visibleRows() {
    const rows = this.itemTargets.filter(li => !li.hidden)
    if (this.hasCreateTarget && !this.createTarget.hidden) rows.push(this.createTarget)
    return rows
  }

  #restoreSearchValueToSelection() {
    const selectedId = this.valueTarget.value
    if (!selectedId) {
      this.searchTarget.value = ""
      return
    }
    const match = this.itemTargets.find(li => li.dataset.value === selectedId)
    if (match) this.searchTarget.value = match.dataset.label
  }

  #createEnabled() {
    return Boolean(this.createValue?.path)
  }

  #createLabelText(term) {
    const prefix = this.createLabelTarget.dataset.prefix || this.createLabelTarget.textContent
    // "Agregar «Mariscos»" — the ERB primes it with plain "Agregar".
    this.createLabelTarget.dataset.prefix = this.createLabelTarget.dataset.prefix || prefix
    return `${this.createLabelTarget.dataset.prefix} «${term}»`
  }

  async #createFromSearchTerm() {
    if (!this.#createEnabled()) return
    const term = this.searchTarget.value.trim()
    if (!term) return

    const body = new FormData()
    body.append("name", term)
    for (const [k, v] of Object.entries(this.createValue.params || {})) {
      body.append(k, v)
    }

    try {
      const res = await fetch(this.createValue.path, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfValue
        },
        body
      })
      if (!res.ok) {
        this.element.dispatchEvent(new CustomEvent("combobox:create-error", { bubbles: true }))
        return
      }
      const payload = await res.json()

      // Append a new <li> to the list so we can select it.
      const id = String(payload.id)
      const label = payload.label
      const li = this.#buildItem(id, label)
      this.listTarget.insertBefore(li, this.hasEmptyTarget ? this.emptyTarget : null)

      // Also append to the datalist so future renders stay in sync.
      if (this.hasOptionsTarget) {
        const opt = document.createElement("option")
        opt.value = id
        opt.dataset.label = label
        opt.textContent = label
        this.optionsTarget.appendChild(opt)
      }

      this.#select(id, label)
      this.close()
    } catch (_e) {
      this.element.dispatchEvent(new CustomEvent("combobox:create-error", { bubbles: true }))
    }
  }

  #buildItem(id, label) {
    const listId = this.listTarget.id
    const li = document.createElement("li")
    li.setAttribute("role", "option")
    li.id = `${listId}-opt-${id}`
    li.dataset.comboboxTarget = "item"
    li.dataset.value = id
    li.dataset.label = label
    li.tabIndex = -1
    li.setAttribute("aria-selected", "false")
    li.setAttribute("data-action", "mousedown->combobox#pickEvent")
    li.className =
      "flex items-center justify-between gap-3 px-3.5 py-2.5 text-[14px] text-ink cursor-pointer " +
      "hover:bg-bg-2/60 aria-selected:bg-accent-soft aria-selected:text-accent " +
      "data-[highlighted]:bg-accent-soft data-[highlighted]:text-accent"
    const inner = document.createElement("span")
    inner.className = "truncate"
    inner.textContent = label
    li.appendChild(inner)
    return li
  }

  #renderCreateRow() {
    // Called on connect so the create row's label text is primed. The
    // datalist change mutation triggers #syncItemsFromOptions which
    // ultimately re-renders if the user typed.
    if (!this.hasCreateLabelTarget) return
    if (!this.createLabelTarget.dataset.prefix) {
      this.createLabelTarget.dataset.prefix = this.createLabelTarget.textContent.trim()
    }
  }

  #syncItemsFromOptions() {
    // If the datalist was updated by a Turbo Stream (category created
    // elsewhere on the page), add missing rows. Pure additive — we
    // don't remove existing list items, so the operator's selection
    // stays intact.
    if (!this.hasOptionsTarget) return
    const existingIds = new Set(this.itemTargets.map(li => li.dataset.value))

    Array.from(this.optionsTarget.options).forEach(opt => {
      if (existingIds.has(opt.value)) return
      const li = this.#buildItem(opt.value, opt.dataset.label || opt.textContent)
      this.listTarget.insertBefore(li, this.hasEmptyTarget ? this.emptyTarget : null)
    })
  }
}
