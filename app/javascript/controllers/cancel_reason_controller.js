import { Controller } from "@hotwired/stimulus"

// Cancel-reason form behavior:
//   - When the reason code is "other", flip the note field to required
//     and surface a small "obligatoria" chip next to its label.
//   - All other codes leave the note as an optional nuance field.
//
// The server also validates (see Orders::Cancel), this is purely for UX.
export default class extends Controller {
  static targets = ["code", "note", "noteWrap", "noteRequired"]

  connect() {
    this.toggleNote()
  }

  toggleNote() {
    const isOther = this.codeTarget.value === "other"
    if (this.hasNoteTarget) {
      this.noteTarget.required = isOther
    }
    if (this.hasNoteRequiredTarget) {
      this.noteRequiredTarget.classList.toggle("hidden", !isOther)
    }
    if (isOther && this.hasNoteTarget) {
      this.noteTarget.focus()
    }
  }
}
