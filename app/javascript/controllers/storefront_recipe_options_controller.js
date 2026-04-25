import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "optionInput", "textareaInput", "removableInput",
    "totalDisplay", "totalRow", "modifiersList", "modifiersSection", "baseLine"
  ]
  static values = { baseCents: Number }

  connect() {
    this.recalc()
  }

  recalc() {
    let delta = 0
    const lines = []

    this.optionInputTargets.forEach(input => {
      if (!input.checked) return
      const d = parseInt(input.dataset.delta || "0", 10)
      delta += d
      if (d !== 0) {
        lines.push({ label: input.dataset.label, delta: d })
      }
    })

    const total = this.baseCentsValue + delta

    this.totalDisplayTargets.forEach(el => {
      el.textContent = this.formatMoney(total)
    })

    if (this.hasModifiersListTarget) {
      this.renderModifiers(lines)
    }
  }

  renderModifiers(lines) {
    if (lines.length === 0) {
      this.modifiersListTarget.innerHTML = ""
      return
    }

    const html = lines.map(line => {
      const sign = line.delta > 0 ? "+" : "−"
      const abs = Math.abs(line.delta)
      const formatted = this.formatMoney(abs)
      return `<div class="flex items-baseline justify-between gap-3 py-1">
        <span class="text-[13px] text-ink-2 truncate">${this.escapeHtml(line.label)}</span>
        <span class="shrink-0 font-mono text-[12.5px] ${line.delta > 0 ? "text-muted" : ""}" style="${line.delta < 0 ? "color: var(--brand-1);" : ""}">${sign}${formatted}</span>
      </div>`
    }).join("")

    this.modifiersListTarget.innerHTML = html
  }

  countChars(event) {
    const textarea = event.target
    const max = parseInt(textarea.dataset.max || "500", 10)
    const counter = textarea.closest("fieldset")?.querySelector("[data-storefront-recipe-options-target='charCounter']")
    if (counter) {
      counter.textContent = `${textarea.value.length}/${max}`
    }
  }

  selectedOptions() {
    const selections = {}
    this.optionInputTargets.forEach(input => {
      if (!input.checked) return
      const name = input.name
      const match = name.match(/options\[([^\]]+)\]/)
      if (!match) return
      const groupId = match[1]
      if (!selections[groupId]) selections[groupId] = []
      selections[groupId].push({
        id: input.value,
        label: input.dataset.label,
        delta: parseInt(input.dataset.delta || "0", 10)
      })
    })
    this.textareaInputTargets.forEach(textarea => {
      if (!textarea.value.trim()) return
      const match = textarea.name.match(/options\[([^\]]+)\]/)
      if (!match) return
      selections[match[1]] = [{ text: textarea.value.trim() }]
    })
    return selections
  }

  removedComponents() {
    return this.removableInputTargets
      .filter(input => input.checked)
      .map(input => input.value)
  }

  totalDeltaCents() {
    let delta = 0
    this.optionInputTargets.forEach(input => {
      if (input.checked) delta += parseInt(input.dataset.delta || "0", 10)
    })
    return delta
  }

  formatMoney(cents) {
    const pesos = cents / 100
    return `$${pesos.toLocaleString("es-MX", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
