import { Controller } from "@hotwired/stimulus"

// One-shot: on connect, tell the storefront cart controller to wipe
// its sessionStorage + re-render the header badge and drawer. Mounted
// on the confirmation page so the customer's just-placed items don't
// keep lingering in the cart after checkout.
//
// Kept as a separate controller (vs. a value on storefront-cart)
// because the clearing signal is *per page* — the main cart controller
// lives at <body> in the storefront layout and shouldn't be toggled
// via a value set from a single template.
export default class extends Controller {
  connect() {
    document.dispatchEvent(new CustomEvent("storefront-cart:clear"))
  }
}
