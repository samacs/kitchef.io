import { Controller } from "@hotwired/stimulus"

/*
 * Storefront checkout — toggles the address block based on the chosen
 * fulfillment type. Pickup hides the address fields AND flips the
 * `required`/`disabled` flags off so browser validation doesn't block
 * a pickup submission on empty delivery inputs. Delivery does the
 * inverse: shows the fields and re-enables the `required` flag on any
 * input flagged via `data-required-when-delivery`.
 *
 * Kept intentionally small — the heavy cart logic lives in
 * `storefront_cart_controller.js`.
 */
export default class extends Controller {
  static targets = ["address", "deliveryField"]

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

    this.deliveryFieldTargets.forEach((field) => {
      // `disabled` fields don't get submitted — which is exactly what
      // we want for pickup (no empty address sneaking into the POST).
      field.disabled = !needsAddress
      if (field.dataset.requiredWhenDelivery === "true") {
        field.required = needsAddress
      }
    })
  }
}
