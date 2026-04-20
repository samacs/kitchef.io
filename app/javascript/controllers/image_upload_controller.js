import { Controller } from "@hotwired/stimulus"

// Handles the upload-card's immediate visual feedback: once a file is
// chosen, the card label swaps to the filename so the operator knows
// the selection registered. The preview panel updates separately via
// the companion live-preview-source controller — both listen for the
// same `change` event.
export default class extends Controller {
  static targets = ["input"]

  preview() {
    if (!this.hasInputTarget) return
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file) return

    const label = this.inputTarget.closest("label")
    if (!label) return

    // Swap the copy spans inside the label so the operator sees the
    // picked file's name. We keep the hint text intact for the
    // size/format reminder.
    const heading = label.querySelector("span.font-medium")
    if (heading) heading.textContent = file.name
  }
}
