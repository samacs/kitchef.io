import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "body", "title", "confirmLabel"]
  static values = { slug: String }

  connect() {
    this.editIndex = null
    this.element.addEventListener("close", this.onClose)
    document.addEventListener("storefront:customize", this.onCustomize)
    document.addEventListener("storefront:customize-edit", this.onCustomizeEdit)
  }

  disconnect() {
    this.element.removeEventListener("close", this.onClose)
    document.removeEventListener("storefront:customize", this.onCustomize)
    document.removeEventListener("storefront:customize-edit", this.onCustomizeEdit)
  }

  onCustomize = (event) => {
    const { recipeSlug } = event.detail
    if (!recipeSlug) return

    this.editIndex = null
    this.loadRecipe(recipeSlug)
    this.element.showModal()
  }

  onCustomizeEdit = (event) => {
    const { recipeSlug, cartIdx } = event.detail
    if (!recipeSlug || cartIdx === undefined) return

    this.editIndex = parseInt(cartIdx, 10)
    this.loadRecipe(recipeSlug, () => this.prefillFromCart(this.editIndex))
    this.element.showModal()
  }

  loadRecipe(recipeSlug, callback) {
    const url = `/${this.slugValue}/dishes/${recipeSlug}/customize`
    this.frameTarget.src = url

    this.frameTarget.addEventListener("turbo:frame-load", () => {
      requestAnimationFrame(() => {
        if (this.hasConfirmLabelTarget) {
          this.confirmLabelTarget.textContent = this.editIndex !== null ? "Actualizar" : "Agregar al carrito"
        }
        if (callback) callback()
      })
    }, { once: true })
  }

  prefillFromCart(idx) {
    const cartCtrl = this.application.getControllerForElementAndIdentifier(
      document.body, "storefront-cart"
    )
    if (!cartCtrl) return

    const item = cartCtrl.cart.items[idx]
    if (!item) return

    if (item.selected_options) {
      Object.entries(item.selected_options).forEach(([groupId, selections]) => {
        Array(selections).flat().forEach(sel => {
          if (!sel || !sel.id) return
          const input = this.element.querySelector(
            `input[name*="options[${groupId}]"][value="${sel.id}"]`
          )
          if (input) {
            input.checked = true
            input.dispatchEvent(new Event("change", { bubbles: true }))
          }
        })
      })
    }

    if (item.removed_components?.length) {
      item.removed_components.forEach(name => {
        const input = this.element.querySelector(
          `input[name="removed_components[]"][value="${CSS.escape(name)}"]`
        )
        if (input) input.checked = true
      })
    }

    const optionsCtrl = this.application.getControllerForElementAndIdentifier(
      this.element.querySelector("[data-controller*='storefront-recipe-options']"),
      "storefront-recipe-options"
    )
    if (optionsCtrl) optionsCtrl.recalc()
  }

  confirm(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const recipeId = btn.dataset.recipeId
    const recipeSlug = btn.dataset.recipeSlug
    const name = btn.dataset.recipeName
    const basePriceCents = parseInt(btn.dataset.basePriceCents, 10)
    const photo = btn.dataset.recipePhoto || null

    const optionsCtrl = this.application.getControllerForElementAndIdentifier(
      this.element.querySelector("[data-controller*='storefront-recipe-options']"),
      "storefront-recipe-options"
    )

    let selectedOptions = null
    let removedComponents = []
    let deltaCents = 0

    if (optionsCtrl) {
      selectedOptions = optionsCtrl.selectedOptions()
      removedComponents = optionsCtrl.removedComponents()
      deltaCents = optionsCtrl.totalDeltaCents()
    }

    const hasCustomizations = (selectedOptions && Object.keys(selectedOptions).length > 0) ||
                              removedComponents.length > 0

    const cartCtrl = this.application.getControllerForElementAndIdentifier(
      document.body, "storefront-cart"
    )
    if (!cartCtrl) return

    const itemData = {
      recipe_id: recipeId,
      recipe_slug: recipeSlug || null,
      name: name,
      price_cents: basePriceCents + deltaCents,
      base_price_cents: basePriceCents,
      photo: photo,
      qty: 1,
      notes: "",
      selected_options: hasCustomizations ? selectedOptions : null,
      removed_components: removedComponents.length > 0 ? removedComponents : null
    }

    if (this.editIndex !== null && this.editIndex >= 0 && this.editIndex < cartCtrl.cart.items.length) {
      itemData.qty = cartCtrl.cart.items[this.editIndex].qty
      cartCtrl.cart.items[this.editIndex] = itemData
    } else {
      cartCtrl.cart.items.push(itemData)
    }

    cartCtrl.save()
    cartCtrl.render()
    this.element.close()
    if (this.editIndex === null) cartCtrl.openDrawer()
  }

  close(event) {
    event?.preventDefault()
    this.element.close()
  }

  onClose = () => {
    this.editIndex = null
    this.frameTarget.innerHTML = `
      <div class="flex items-center justify-center py-12">
        <div class="h-6 w-6 animate-spin rounded-full border-2 border-line border-t-[var(--brand-1)]"></div>
      </div>
    `
    this.frameTarget.removeAttribute("src")
  }
}
