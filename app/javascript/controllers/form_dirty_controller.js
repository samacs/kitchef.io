import { Controller } from "@hotwired/stimulus"

// Tracks unsaved changes on a form and warns before navigating away.
//
// Usage:
//   <form data-controller="form-dirty"
//         data-form-dirty-message-value="Tienes cambios sin guardar. ¿Salir sin guardar?">
//
// Monitors all input/select/textarea changes inside the form. When the
// form is dirty:
//   - `beforeunload` fires the browser's native "leave page?" dialog
//   - Turbo's `turbo:before-visit` shows a confirm() with the custom message
//   - The submit button gets a subtle visual pulse so the operator notices
//
// Submitting the form clears the dirty flag so the redirect goes through
// without a warning.

export default class extends Controller {
  static values = {
    message: { type: String, default: "Tienes cambios sin guardar. ¿Salir sin guardar?" }
  }

  static targets = ["indicator"]

  connect() {
    this.dirty = false
    this.submitted = false

    this.onBeforeUnload = this.handleBeforeUnload.bind(this)
    this.onTurboVisit = this.handleTurboVisit.bind(this)

    this.element.addEventListener("input", this.markDirty)
    this.element.addEventListener("change", this.markDirty)
    this.element.addEventListener("submit", this.markSubmitted)
    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("turbo:before-visit", this.onTurboVisit)
  }

  disconnect() {
    this.element.removeEventListener("input", this.markDirty)
    this.element.removeEventListener("change", this.markDirty)
    this.element.removeEventListener("submit", this.markSubmitted)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.onTurboVisit)
  }

  markDirty = () => {
    if (this.dirty) return
    this.dirty = true
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.hidden = false
    }
  }

  markSubmitted = () => {
    this.submitted = true
    this.dirty = false
  }

  handleBeforeUnload(event) {
    if (!this.dirty || this.submitted) return
    event.preventDefault()
    event.returnValue = this.messageValue
  }

  handleTurboVisit(event) {
    if (!this.dirty || this.submitted) return
    if (!confirm(this.messageValue)) {
      event.preventDefault()
    }
  }
}
