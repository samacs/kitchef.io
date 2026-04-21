import { Controller } from "@hotwired/stimulus"

/*
 * Storefront checkout — toggles the address block based on the chosen
 * fulfillment type. Pickup hides address fields entirely; delivery and
 * shipping both expose them. Kept intentionally small — the heavy cart
 * logic lives in `storefront_cart_controller.js`.
 */
export default class extends Controller {
  static targets = ["address"]

  connect() {
    this.sync()
  }

  fulfillmentChanged() {
    this.sync()
  }

  sync() {
    const radios = this.element.querySelectorAll('input[type="radio"][name="order[delivery_type]"]')
    const selected = Array.from(radios).find(r => r.checked)
    const needsAddress = selected && selected.value === "delivery"
    if (this.hasAddressTarget) {
      this.addressTarget.hidden = !needsAddress
    }
  }
}
