import { Controller } from "@hotwired/stimulus"

// Tiny wrapper around the Clipboard API. Swaps the button label to the
// configured success copy for ~2s after a successful copy. Used by the
// "Compartir ruta del día" button on /production so the operator knows
// her nephew's runner URL is on the clipboard without a popup.
export default class extends Controller {
  static targets = ["button"]
  static values = {
    value: String,
    successLabel: String
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.valueValue)
      this.#flashSuccess()
    } catch (err) {
      console.warn("copy-to-clipboard: write failed", err)
    }
  }

  #flashSuccess() {
    if (!this.hasButtonTarget) return
    const button = this.buttonTarget
    const labelEl = button.querySelector("span") || button
    const original = labelEl.textContent
    labelEl.textContent = this.successLabelValue || "Copiado"
    clearTimeout(this._resetTimer)
    this._resetTimer = setTimeout(() => {
      labelEl.textContent = original
    }, 2000)
  }
}
