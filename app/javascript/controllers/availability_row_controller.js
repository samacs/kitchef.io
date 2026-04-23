import { Controller } from "@hotwired/stimulus"

// A single availability row on /schedule. Plain <div> (not a <form>) so
// we can coexist with other forms on the page without nesting. Handles
// two behaviors:
//
//   * save — debounced PATCH when any field inside the row changes
//   * delete — DELETE on click, server returns Turbo Stream that removes
//     the row from the DOM
//
// Status copy (Guardando/Guardado) shows inline on the row so the
// operator sees confirmation per-window, not for the whole page at once.
export default class extends Controller {
  static targets = ["field", "status"]
  static values = {
    updateUrl: String,
    destroyUrl: String,
    destroyConfirm: String
  }

  save() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.#submit(), 600)
  }

  async delete(event) {
    event.preventDefault()
    if (this.destroyConfirmValue && !window.confirm(this.destroyConfirmValue)) return

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    const res = await fetch(this.destroyUrlValue, {
      method: "DELETE",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrf || "",
        "X-Requested-With": "XMLHttpRequest"
      },
      credentials: "same-origin"
    })

    if (res.ok) {
      const stream = await res.text()
      window.Turbo.renderStreamMessage(stream)
    } else {
      this.#showStatus("error")
    }
  }

  async #submit() {
    this.#showStatus("saving")

    const body = new FormData()
    this.fieldTargets.forEach((field) => {
      if (field.type === "checkbox") {
        body.append(field.name, field.checked ? (field.value || "1") : "0")
      } else if (field.type === "radio") {
        if (field.checked) body.append(field.name, field.value)
      } else {
        body.append(field.name, field.value)
      }
    })

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const res = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": csrf || "",
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })
      this.#showStatus(res.ok ? "saved" : "error")
    } catch (_err) {
      this.#showStatus("error")
    }
  }

  #showStatus(kind) {
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
