import { Controller } from "@hotwired/stimulus"

// Live ingredient-impact preview for the new-batch form. Watches the
// recipe picker + quantity input; when either changes, builds a fresh
// query string and rewrites the embedded turbo-frame's `src` so it
// re-fetches `/batches/impact` and renders the latest "te faltan X" /
// "todo listo" message — without a full page navigation.
//
// Debounced 250ms so typing "12" doesn't fire two requests.
export default class extends Controller {
  static targets = ["recipe", "quantity"]
  static values = { impactUrl: String }

  initialize() {
    this.refreshImpact = this.debounce(this.refreshImpact.bind(this), 250)
  }

  refreshImpact() {
    const frame = document.getElementById("batch_impact_preview")
    if (!frame) return

    const recipeId = this.recipeTarget.value
    const quantity = this.quantityTarget.value

    if (!recipeId || !quantity || Number(quantity) <= 0) {
      // Empty state — clear the frame by pointing at the URL with no
      // params; the controller renders an empty turbo-frame.
      frame.src = this.impactUrlValue
      return
    }

    const params = new URLSearchParams({ recipe_id: recipeId, quantity })
    frame.src = `${this.impactUrlValue}?${params}`
  }

  debounce(fn, ms) {
    let timeout
    return (...args) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => fn(...args), ms)
    }
  }
}
