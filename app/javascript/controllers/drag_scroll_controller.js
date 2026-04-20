import { Controller } from "@hotwired/stimulus"

// Mouse/touch drag-to-scroll for horizontally-overflowing lists (the
// kanban on /orders is the first caller — touch devices already pan
// natively, but desktops need explicit drag behavior to match that
// phone-first feel).
//
// A small drag threshold (6px) prevents short clicks on child cards
// from being swallowed: the controller only engages scroll mode once
// the pointer has moved past the threshold, after which the original
// click is suppressed.
export default class extends Controller {
  static values = { threshold: { type: Number, default: 6 } }

  initialize() {
    this.dragging = false
    this.startX = 0
    this.startScroll = 0
    this.moved = 0
  }

  connect() {
    this.element.classList.add("cursor-grab", "select-none")
    this.onPointerDown = (e) => this.pointerDown(e)
    this.onPointerMove = (e) => this.pointerMove(e)
    this.onPointerUp = (e) => this.pointerUp(e)
    this.onClickCapture = (e) => this.clickCapture(e)

    this.element.addEventListener("pointerdown", this.onPointerDown)
    window.addEventListener("pointermove", this.onPointerMove)
    window.addEventListener("pointerup", this.onPointerUp)
    this.element.addEventListener("click", this.onClickCapture, true)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onPointerDown)
    window.removeEventListener("pointermove", this.onPointerMove)
    window.removeEventListener("pointerup", this.onPointerUp)
    this.element.removeEventListener("click", this.onClickCapture, true)
    this.element.classList.remove("cursor-grab", "cursor-grabbing", "select-none")
  }

  pointerDown(event) {
    // Only engage for primary mouse button / primary touch.
    if (event.pointerType === "mouse" && event.button !== 0) return
    // Don't hijack native inputs — the user might be clicking a button
    // or typing into a search field embedded in a scroll container.
    if (event.target.closest("input, textarea, select, button, a[href], [role='menuitem'], [contenteditable='true']")) return

    this.dragging = true
    this.moved = 0
    this.startX = event.pageX
    this.startScroll = this.element.scrollLeft
    this.element.classList.remove("cursor-grab")
    this.element.classList.add("cursor-grabbing")
  }

  pointerMove(event) {
    if (!this.dragging) return
    const dx = event.pageX - this.startX
    this.moved = Math.max(this.moved, Math.abs(dx))
    if (this.moved < this.thresholdValue) return
    event.preventDefault()
    this.element.scrollLeft = this.startScroll - dx
  }

  pointerUp() {
    if (!this.dragging) return
    this.dragging = false
    this.element.classList.remove("cursor-grabbing")
    this.element.classList.add("cursor-grab")
    // moved is read by clickCapture (fires right after pointerup in the
    // same event loop turn) and reset on the next pointerdown.
  }

  clickCapture(event) {
    // Suppress the click that bookends a real drag — without this, the
    // pointerup after a drag fires a click on whichever card was under
    // the cursor and the drawer pops open unexpectedly.
    if (this.moved >= this.thresholdValue) {
      event.stopPropagation()
      event.preventDefault()
      this.moved = 0
    }
  }
}
