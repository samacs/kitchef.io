import { Controller } from "@hotwired/stimulus"

// Clear every <input type=file> after the parent form-autosave fires
// a successful save. Without this, every keystroke-triggered autosave
// would re-upload whatever file the operator picked earlier — a typed
// description change shouldn't force a fresh round-trip of a 3MB JPEG.
//
// Listens for the `form-autosave:success` custom event dispatched by
// form_autosave_controller. Wire this onto the form root alongside
// form-autosave.
export default class extends Controller {
  connect() {
    this.handler = this.reset.bind(this)
    this.element.addEventListener("form-autosave:success", this.handler)
  }

  disconnect() {
    this.element.removeEventListener("form-autosave:success", this.handler)
  }

  reset() {
    this.element.querySelectorAll('input[type="file"]').forEach((input) => {
      input.value = ""
    })
  }
}
