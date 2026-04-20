import { Controller } from "@hotwired/stimulus"

// Attaches to forms (onboarding + account config) and emits
// `livepreview:update` events on every field change. The receiver
// (live-preview controller) listens and mutates the preview DOM.
//
// Event payload: { field, value, url?, meta? }.
//
// Text/textarea inputs carry a `data-live-preview-source-field-param`
// naming the field. File inputs also carry that param; on change the
// controller reads the first selected File and publishes a data URL so
// the preview can render without waiting for an upload round-trip.
//
// Radio groups (palette picker, theme default) emit only the checked
// value. Because radios don't fire `change` when a *different* one gets
// checked under the same Stimulus root by default, we bind `change`
// to each input via `data-action` in the view.
export default class extends Controller {
  emit(event) {
    const input = event.currentTarget
    const field = input.dataset.livePreviewSourceFieldParam

    if (!field) return

    if (input.type === "file") {
      this.#emitFile(field, input)
    } else if (input.type === "radio" || input.type === "checkbox") {
      if (!input.checked) return
      this.#dispatch({ field, value: input.value })
    } else {
      this.#dispatch({ field, value: input.value })
    }
  }

  #emitFile(field, input) {
    const file = input.files && input.files[0]
    if (!file) {
      this.#dispatch({ field, value: null, url: null })
      return
    }

    const reader = new FileReader()
    reader.onload = () => this.#dispatch({ field, value: file.name, url: reader.result })
    reader.readAsDataURL(file)
  }

  #dispatch(detail) {
    document.dispatchEvent(new CustomEvent("livepreview:update", { detail }))
  }
}
