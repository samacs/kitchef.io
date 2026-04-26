import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["transferToggle", "transferFields", "cardToggle", "cardFields"]

  toggleTransfer() {
    this.transferFieldsTarget.classList.toggle("hidden", !this.transferToggleTarget.checked)
  }

  toggleCard() {
    this.cardFieldsTarget.classList.toggle("hidden", !this.cardToggleTarget.checked)
  }
}
