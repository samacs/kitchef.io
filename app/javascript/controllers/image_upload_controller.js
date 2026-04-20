import { Controller } from "@hotwired/stimulus"

// Immediate visual feedback for file-input upload cards:
//   - Swaps the card heading to the chosen filename.
//   - If a `preview` target (<img>) is present, reads the file with
//     FileReader and sets its src to a local data URL so the operator
//     sees the picked image before submitting.
//   - If a `placeholder` target is present, it's hidden once a preview
//     is shown (used to swap a big upload icon for the image).
//
// The companion live-preview-source controller (onboarding) listens for
// the same `change` event to update a sibling preview panel.
export default class extends Controller {
  static targets = ["input", "preview", "placeholder"]

  preview() {
    if (!this.hasInputTarget) return
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file) return

    const label = this.inputTarget.closest("label")
    if (label) {
      const heading = label.querySelector("span.font-medium")
      if (heading) heading.textContent = file.name
    }

    if (this.hasPreviewTarget) {
      const reader = new FileReader()
      reader.onload = (event) => {
        this.previewTarget.src = event.target.result
        this.previewTarget.classList.remove("hidden")
        if (this.hasPlaceholderTarget) {
          this.placeholderTarget.classList.add("hidden")
        }
      }
      reader.readAsDataURL(file)
    }
  }
}
