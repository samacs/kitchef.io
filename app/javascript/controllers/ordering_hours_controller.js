import { Controller } from "@hotwired/stimulus"

// Weekly ordering-hours editor. Listens for open/close time edits + the
// "Cerrado" toggle per row and writes a single JSON payload to the
// hidden `account[public_profile][ordering_hours]` input. The change
// event on that input bubbles up to the parent form's `form-autosave`
// controller, which debounces the resulting POST.
//
// Expected markup (see ordering_hours_editor_component.html.erb):
//   <div data-controller="ordering-hours">
//     <input type="hidden" data-ordering-hours-target="payload" name="…">
//     <div data-ordering-hours-target="row" data-wday="1">
//       <input data-ordering-hours-target="open">
//       <input data-ordering-hours-target="close">
//       <input type="checkbox" data-ordering-hours-target="closedToggle">
//     </div>
//     …
//   </div>
export default class extends Controller {
  static targets = ["root", "payload", "row", "open", "close", "closedToggle"]

  toggleClosed(event) {
    const checkbox = event.currentTarget
    const row = checkbox.closest("[data-ordering-hours-target='row']")
    if (!row) return

    const openInput  = row.querySelector("[data-ordering-hours-target='open']")
    const closeInput = row.querySelector("[data-ordering-hours-target='close']")
    const closed = checkbox.checked

    row.dataset.closed = closed
    if (openInput)  openInput.disabled = closed
    if (closeInput) closeInput.disabled = closed

    this.serialize()
  }

  serialize() {
    const payload = {}
    this.rowTargets.forEach((row) => {
      const wday = row.dataset.wday
      if (wday == null) return

      const closed = row.dataset.closed === "true"
      if (closed) {
        payload[wday] = "closed"
        return
      }

      const open  = row.querySelector("[data-ordering-hours-target='open']")?.value || ""
      const close = row.querySelector("[data-ordering-hours-target='close']")?.value || ""
      payload[wday] = { open, close }
    })

    if (this.hasPayloadTarget) {
      this.payloadTarget.value = JSON.stringify(payload)
      // Explicit change event so the parent form-autosave picks it up —
      // programmatic `value=` assignments don't fire change.
      this.payloadTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }
}
