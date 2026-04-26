import { Controller } from "@hotwired/stimulus"

// Reveals/hides the propina-presets sub-panel as the operator flips the
// "Acepto propinas" checkbox in /account/edit. Pure UI — the presets
// stay persisted in the form fields either way, so re-enabling tips
// restores the previously-configured percentages.
export default class extends Controller {
  static targets = ["checkbox", "presets"]

  toggle() {
    this.presetsTarget.classList.toggle("hidden", !this.checkboxTarget.checked)
  }
}
