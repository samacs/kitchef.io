import { Controller } from "@hotwired/stimulus"

// Live character counter for the onboarding description textarea.
// Reads max from a data value; the numeric counter is updated on every
// keystroke and turns amber when the remaining budget drops below 10%.
export default class extends Controller {
  static targets = ["count"]
  static values  = { max: Number }

  update(event) {
    const value = event.target.value || ""
    if (this.hasCountTarget) this.countTarget.textContent = value.length

    const remaining = this.maxValue - value.length
    const parent = this.countTarget?.parentElement
    if (!parent) return

    parent.classList.toggle("text-warn", remaining < Math.max(10, this.maxValue * 0.1))
    parent.classList.toggle("text-err",  remaining < 0)
  }
}
