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
  static targets = ["input", "preview", "placeholder", "submit"]

  saleableChanged(event) {
    const saleable = event.target.checked
    const priceField = document.getElementById("recipe_sale_price_field")
    const priceInput = document.getElementById("recipe_sale_price")
    if (priceField) {
      priceField.classList.toggle("hidden", !saleable)
    }
    if (priceInput) {
      priceInput.required = saleable
      if (!saleable) priceInput.value = ""
    }
  }

  publishGate(event) {
    const count = event.detail?.count ?? 0
    const checkbox = document.getElementById("recipe_is_published")
    const label = checkbox?.closest("label")
    if (!checkbox) return

    checkbox.disabled = count === 0
    label?.classList.toggle("opacity-60", count === 0)
  }

  preview() {
    if (!this.hasInputTarget) return
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file) return

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove("opacity-50", "pointer-events-none")
    }

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
