import { Controller } from "@hotwired/stimulus"

// Auto-save the drawer form on every field change. Change events bubble
// to the form, so we listen once at the form level and let the default
// delegation pick up inputs, selects, textareas. Select + date inputs
// fire `change` on commit; text inputs fire on blur — both are the
// natural "I'm done with this field" moment, which is the right save
// trigger. Avoids flooding the server on every keystroke.
//
// The optional `status` target surfaces the save state (Guardando… →
// Guardado) so operators get a quiet confirmation without a button.
export default class extends Controller {
  static targets = ["status"]

  connect() {
    this.onSubmitEnd = (event) => {
      this.showStatus(event.detail?.success ? "saved" : "error")
    }
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    clearTimeout(this.debounceTimer)
    clearTimeout(this.hideTimer)
  }

  // Fires on every `change` event bubbled up from form fields. A tiny
  // debounce coalesces rapid consecutive changes (e.g. multi-select or
  // a date picker that fires twice) into one POST.
  save(event) {
    if (event.target.closest("button, [data-form-autosave-skip]")) return

    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.showStatus("saving")
      this.element.requestSubmit()
    }, 120)
  }

  showStatus(kind) {
    if (!this.hasStatusTarget) return
    const labels = {
      saving: this.statusTarget.dataset.labelSaving || "Guardando…",
      saved:  this.statusTarget.dataset.labelSaved  || "Guardado",
      error:  this.statusTarget.dataset.labelError  || "No se pudo guardar"
    }
    this.statusTarget.textContent = labels[kind]
    this.statusTarget.dataset.state = kind
    this.statusTarget.classList.remove("hidden")

    clearTimeout(this.hideTimer)
    if (kind === "saved") {
      this.hideTimer = setTimeout(() => this.statusTarget.classList.add("hidden"), 1800)
    }
  }
}
