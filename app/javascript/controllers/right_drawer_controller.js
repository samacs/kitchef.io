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
//
// Width toggle: the operator can expand the drawer to a wider view for
// forms that benefit from more space. The preference persists in
// localStorage so the drawer reopens at the last-used width.
export default class extends Controller {
  static targets = ["panel", "backdrop", "frame", "widthToggle", "expandIcon", "shrinkIcon"]

  static classes = {
    narrow: "sm:w-[640px] lg:w-[720px]",
    wide: "sm:w-[900px] lg:w-[1040px]"
  }

  initialize() {
    this.isOpen = false
    this.isWide = false
  }

  connect() {
    this.onKey = (event) => {
      if (event.key === "Escape" && this.isOpen) this.close()
    }
    document.addEventListener("keydown", this.onKey)

    this.observer = new MutationObserver(() => this.onFrameChanged())
    this.observer.observe(this.frameTarget, { childList: true })

    this.restoreWidthPreference()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    this.observer?.disconnect()
  }

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
    event?.preventDefault?.()
    this.isOpen = false
    this.element.classList.add("pointer-events-none")
    this.backdropTarget.classList.add("opacity-0")
    this.panelTarget.classList.add("translate-x-full")
    document.body.classList.remove("overflow-hidden")
    window.setTimeout(() => {
      if (!this.isOpen) this.frameTarget.innerHTML = ""
    }, 220)
  }

  toggleWidth(event) {
    event?.preventDefault?.()
    this.isWide = !this.isWide
    this.applyWidth()
    this.saveWidthPreference()
  }

  applyWidth() {
    const panel = this.panelTarget
    if (this.isWide) {
      panel.classList.remove("sm:w-[640px]", "lg:w-[720px]")
      panel.classList.add("sm:w-[900px]", "lg:w-[1040px]")
    } else {
      panel.classList.remove("sm:w-[900px]", "lg:w-[1040px]")
      panel.classList.add("sm:w-[640px]", "lg:w-[720px]")
    }
    this.updateWidthIcons()
  }

  updateWidthIcons() {
    if (this.hasExpandIconTarget) this.expandIconTarget.classList.toggle("hidden", this.isWide)
    if (this.hasShrinkIconTarget) this.shrinkIconTarget.classList.toggle("hidden", !this.isWide)

    if (this.hasWidthToggleTarget) {
      const key = this.isWide ? "panel.drawer.shrink" : "panel.drawer.expand"
      this.widthToggleTarget.setAttribute("aria-label", this.isWide ? "Reducir panel" : "Ampliar panel")
      this.widthToggleTarget.setAttribute("title", this.isWide ? "Reducir panel" : "Ampliar panel")
    }
  }

  saveWidthPreference() {
    try {
      localStorage.setItem("kitchef_drawer_wide", this.isWide ? "1" : "0")
    } catch { /* localStorage unavailable */ }
  }

  restoreWidthPreference() {
    try {
      this.isWide = localStorage.getItem("kitchef_drawer_wide") === "1"
    } catch {
      this.isWide = false
    }
    this.applyWidth()
  }

  onFrameChanged() {
    const hasContent = this.frameTarget.children.length > 0
    if (hasContent && !this.isOpen) this.open()
    else if (!hasContent && this.isOpen) this.close()
  }
}
