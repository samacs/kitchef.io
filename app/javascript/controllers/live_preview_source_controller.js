import { Controller } from "@hotwired/stimulus"

// Attaches to onboarding forms and emits `livepreview:update` events on
// every field change. The storefront preview (live-preview-controller,
// usually in a sibling aside) listens and mutates the preview DOM.
//
// Text/textarea inputs carry a `data-live-preview-source-field-param`
// naming the field. File inputs also carry that param; on change the
// controller reads the first selected File and publishes a data URL so
// the preview can render without waiting for an upload round-trip.
export default class extends Controller {
  emit(event) {
    const input = event.currentTarget
    const field = input.dataset.livePreviewSourceFieldParam

    if (!field) return

    if (input.type === "file") {
      this.#emitFile(field, input)
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
