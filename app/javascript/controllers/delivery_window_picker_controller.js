import { Controller } from "@hotwired/stimulus"

// Controls the three-branch delivery-window picker on storefront checkout.
//
// Two pieces of state:
//   1. `branch` — "hoy" (ASAP) or "despues" (scheduled). In `advance`
//      mode only `despues` ever renders; in `same_day` only `hoy`; in
//      `both` the segmented control flips between them.
//   2. the selected `delivery_window_id` — written into a hidden input
//      that the form posts. Server re-decodes on submit via
//      `Schedules::AvailableWindows.decode`, so a tampered value fails
//      validation gracefully rather than booking a phantom slot.
//
// Date-chip selection swaps which time-grid is visible; time-chip
// selection writes the id. Picking ASAP flips the branch + writes the
// id in one gesture.
export default class extends Controller {
  static targets = [
    "hidden",
    "segment",
    "branchHoy",
    "branchDespues",
    "asap",
    "dayChip",
    "timeGrid",
    "timeRadio",
    "switchToLater"
  ]
  static values = { initialBranch: String }

  connect() {
    this.branch = this.initialBranchValue || "hoy"
    this.#syncSegmented()
  }

  selectBranch(event) {
    const branch = event.currentTarget.dataset.branch
    this.#switchTo(branch)
  }

  // Nudge from the "kitchen is closed today" inline state → jump to the
  // "Para después" branch so the customer doesn't think the order page
  // is dead.
  gotoLater(event) {
    event.preventDefault()
    this.#switchTo("despues")
    this.#pickFirstLaterWindow()
  }

  selectAsap(event) {
    if (!event.target.checked) return
    this.hiddenTarget.value = event.target.value
    this.#emitChange()
  }

  selectDay(event) {
    const chip = event.currentTarget
    const date = chip.dataset.date

    // Chip pressed-state update
    this.dayChipTargets.forEach((el) => {
      const active = el.dataset.date === date
      el.setAttribute("aria-pressed", active ? "true" : "false")
      if (active) {
        el.classList.add("kc-day-chip--active")
        this.#activeStyle(el)
      } else {
        el.classList.remove("kc-day-chip--active")
        this.#inactiveStyle(el)
      }
    })

    // Show only the matching time grid
    let picked = null
    this.timeGridTargets.forEach((grid) => {
      const match = grid.dataset.date === date
      grid.hidden = !match
      grid.classList.toggle("hidden", !match)
      if (match) picked = grid
    })

    if (!picked) return

    // Auto-select first time in the newly-revealed grid so the form
    // always has a valid id.
    const firstRadio = picked.querySelector("input[type='radio']")
    if (firstRadio) {
      firstRadio.checked = true
      this.hiddenTarget.value = firstRadio.value
      this.#emitChange()
    }
  }

  selectTime(event) {
    if (!event.target.checked) return
    this.hiddenTarget.value = event.target.value
    this.#emitChange()
  }

  // ── private ─────────────────────────────────────────────────────

  #switchTo(branch) {
    this.branch = branch
    if (this.hasBranchHoyTarget) {
      this.branchHoyTarget.hidden = branch !== "hoy"
      this.branchHoyTarget.classList.toggle("hidden", branch !== "hoy")
    }
    if (this.hasBranchDespuesTarget) {
      this.branchDespuesTarget.hidden = branch !== "despues"
      this.branchDespuesTarget.classList.toggle("hidden", branch !== "despues")
    }
    this.#syncSegmented()

    // Restore the hidden id to whatever the now-visible branch has
    // checked. Without this, switching branches would leave the hidden
    // id pointing at the other branch's selection.
    if (branch === "hoy" && this.hasAsapTarget) {
      this.asapTarget.checked = true
      this.hiddenTarget.value = this.asapTarget.value
      this.#emitChange()
    } else if (branch === "despues") {
      const checked = this.timeRadioTargets.find((r) => r.checked)
      if (checked) {
        this.hiddenTarget.value = checked.value
        this.#emitChange()
      }
    }
  }

  #pickFirstLaterWindow() {
    const firstRadio = this.timeRadioTargets[0]
    if (!firstRadio) return
    firstRadio.checked = true
    this.hiddenTarget.value = firstRadio.value
    this.#emitChange()
  }

  #syncSegmented() {
    if (!this.hasSegmentTarget) return
    this.segmentTargets.forEach((btn) => {
      const active = btn.dataset.branch === this.branch
      btn.dataset.state = active ? "active" : "inactive"
      btn.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  #activeStyle(el) {
    el.style.borderColor = "var(--brand-1)"
    el.style.background  = "var(--brand-1-soft)"
    const kicker = el.querySelector("span:nth-child(1)")
    const number = el.querySelector("span:nth-child(2)")
    if (kicker) kicker.style.color = "var(--brand-1)"
    if (number) number.style.color = "var(--brand-1)"
  }

  #inactiveStyle(el) {
    el.style.borderColor = "var(--color-line)"
    el.style.background  = "var(--color-surface)"
    const kicker = el.querySelector("span:nth-child(1)")
    const number = el.querySelector("span:nth-child(2)")
    if (kicker) kicker.style.color = "var(--color-muted)"
    if (number) number.style.color = "var(--color-ink)"
  }

  #emitChange() {
    // Form-level listeners (e.g. a live total summary later on) can
    // subscribe to this bubbling event instead of tracking individual
    // radio changes.
    this.element.dispatchEvent(new CustomEvent("delivery-window:change", {
      bubbles: true,
      detail: { id: this.hiddenTarget.value }
    }))
  }
}
