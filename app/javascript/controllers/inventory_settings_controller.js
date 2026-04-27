import { Controller } from "@hotwired/stimulus"

// Toggles the secondary inventory controls (oversell policy, low-stock
// threshold, default run window) in/out when the master switch flips.
// The form-autosave controller handles persistence — we only show/hide.
export default class extends Controller {
  static targets = ["checkbox", "details"]

  toggle() {
    this.detailsTarget.classList.toggle("hidden", !this.checkboxTarget.checked)
  }
}
