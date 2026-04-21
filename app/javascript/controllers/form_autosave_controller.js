import { Controller } from "@hotwired/stimulus"

// Auto-save the form on every field change. Both `change` (for selects,
// radios, file pickers) and `input` (for text-as-you-type) bubble to
// the form root, so one listener covers both. A 600ms debounce
// coalesces a typing burst into one POST — long enough to wait out a
// full word, short enough that clicking "Ver mi tienda" still catches
// the last edit before navigation.
//
// We submit via `fetch()` with an explicit `X-CSRF-Token` header rather
// than `requestSubmit()` because multipart forms (e.g. /account with
// logo + cover file fields) don't reliably surface the form's
// `authenticity_token` field to Rails' CSRF check — Rails can't decode
// the token from a multipart body, and Turbo doesn't always set the
// header for form submissions with `_method` overrides. An explicit
// fetch with the meta-tag token is predictable across every form shape.
//
// The optional `status` target surfaces the save state (Guardando… →
// Guardado) so operators get a quiet confirmation without a button.
export default class extends Controller {
  static targets = ["status"]

  connect() {
    // keep around for reset-files-on-save + similar companion controllers
    this.onSubmitEndDispatched = new Event("form-autosave:submit-end")
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
    clearTimeout(this.hideTimer)
  }

  // Fires on every `change` event bubbled up from form fields. A tiny
  // debounce coalesces rapid consecutive changes (e.g. multi-select or
  // a date picker that fires twice) into one POST.
  save(event) {
    if (event.target.closest("button, [data-form-autosave-skip]")) return

    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.#submit(), 600)
  }

  async #submit() {
    this.showStatus("saving")

    const form = this.element
    const formData = new FormData(form)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const res = await fetch(form.action, {
        method: form.method.toUpperCase() || "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": csrfToken || "",
          "X-Requested-With": "XMLHttpRequest"
        },
        body: formData,
        credentials: "same-origin"
      })

      if (res.ok) {
        this.showStatus("saved")
        this.#dispatchSuccess()
      } else {
        this.showStatus("error")
      }
    } catch (_err) {
      // Network failure — "No se pudo guardar" so the operator knows to
      // retry manually. We don't auto-retry; a flaky connection would
      // just replay stale values.
      this.showStatus("error")
    }
  }

  // Custom event consumers (e.g. reset-files-on-save) can listen for
  // rather than coupling to Turbo's `turbo:submit-end` — which this
  // controller no longer emits since we bypass requestSubmit().
  #dispatchSuccess() {
    this.element.dispatchEvent(new CustomEvent("form-autosave:success", { bubbles: true }))
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
