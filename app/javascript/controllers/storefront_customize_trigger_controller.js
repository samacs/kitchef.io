import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    event.preventDefault()
    const slug = this.element.dataset.recipeSlug
    if (!slug) return
    document.dispatchEvent(new CustomEvent("storefront:customize", {
      detail: { recipeSlug: slug }
    }))
  }

  edit(event) {
    event.preventDefault()
    const slug = this.element.dataset.recipeSlug
    const cartIdx = this.element.dataset.cartIdx
    if (!slug || cartIdx === undefined) return
    document.dispatchEvent(new CustomEvent("storefront:customize-edit", {
      detail: { recipeSlug: slug, cartIdx: cartIdx }
    }))
  }
}
