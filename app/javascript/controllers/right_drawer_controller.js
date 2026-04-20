import { Controller } from "@hotwired/stimulus"

// Persistent right-side drawer mounted once by the panel layout. Any
// link that wants to open inside the drawer declares:
//   data-turbo-frame="drawer_content"
//   data-action="click->right-drawer#open"
// (the `drawer_link_to` helper stamps both).
//
// The drawer slides open on click and closes when:
//   • the user hits Esc
//   • the user clicks the backdrop or close button
//   • a Turbo Stream empties the `drawer_content` frame on a successful
//     form submit — the MutationObserver below watches the frame for
//     zero children and slides out in response.
export default class extends Controller {
  static targets = ["panel", "backdrop", "frame"]

  initialize() {
    this.isOpen = false
  }

  connect() {
    this.onKey = (event) => {
      if (event.key === "Escape" && this.isOpen) this.close()
    }
    document.addEventListener("keydown", this.onKey)

    this.observer = new MutationObserver(() => this.onFrameChanged())
    this.observer.observe(this.frameTarget, { childList: true })
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    this.observer?.disconnect()
  }

  // Action target for callers — slides the panel open. Turbo loads the
  // frame content in parallel (driven by `data-turbo-frame` on the
  // clicked element), so the reveal happens in an already-open panel
  // rather than showing then re-rendering.
  open() {
    if (this.isOpen) return
    this.isOpen = true
    this.element.classList.remove("pointer-events-none")
    this.backdropTarget.classList.remove("opacity-0")
    this.panelTarget.classList.remove("translate-x-full")
    document.body.classList.add("overflow-hidden")
  }

  close(event) {
    if (!this.isOpen) return
    // When fired from a link (e.g. the form's "Cancelar"), swallow the
    // default navigation — inside the drawer the user means "dismiss",
    // not "take me to /orders". On a standalone (non-drawer) render
    // isOpen is false so the early-return above preserves normal link
    // behavior.
    event?.preventDefault?.()
    this.isOpen = false
    this.element.classList.add("pointer-events-none")
    this.backdropTarget.classList.add("opacity-0")
    this.panelTarget.classList.add("translate-x-full")
    document.body.classList.remove("overflow-hidden")
    // Empty the frame after the slide-out finishes so the next open
    // doesn't flash the previous entity's stale form.
    window.setTimeout(() => {
      if (!this.isOpen) this.frameTarget.innerHTML = ""
    }, 220)
  }

  // MutationObserver callback — mirrors the two signals we care about:
  //   • frame gets content  → open the drawer (belt-and-suspenders in case
  //     the link didn't carry the explicit `click->right-drawer#open`
  //     action, or the Stimulus registry hadn't caught up yet).
  //   • frame goes empty    → close the drawer (the server signals a
  //     successful save by rendering `<turbo-stream action="update"
  //     target="drawer_content"></turbo-stream>`).
  onFrameChanged() {
    const hasContent = this.frameTarget.children.length > 0
    if (hasContent && !this.isOpen) this.open()
    else if (!hasContent && this.isOpen) this.close()
  }
}
