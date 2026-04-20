import { Controller } from "@hotwired/stimulus"

/*
 * Controls the auto-dismiss timeline for Ui::FlashComponent.
 *
 * Behavior:
 *   - On connect, if `auto` is true and `delay` > 0, start a countdown.
 *   - On mouseenter (pause), cancel the pending timer and record the
 *     elapsed time so a re-hover doesn't reset progress mid-read.
 *   - On mouseleave (resume), start a fresh timer for the remaining
 *     window. (Hover pause that doesn't reset on leave felt laggy in
 *     testing — people want the flash to go away once they're done
 *     reading, not sit there indefinitely.)
 *   - On click of the × button (dismiss), animate out and remove the
 *     node immediately.
 *
 * Accessibility:
 *   - The × button is the authoritative dismissal path; keyboard users
 *     never need to hover. Tab-focus on the button also pauses the
 *     timer via `focusin`/`focusout` because screen-reader users
 *     frequently land on the flash after a redirect.
 */
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 5000 },
    auto:  { type: Boolean, default: true }
  }

  connect() {
    this.remaining = this.delayValue
    this.startedAt = null
    this.timer = null

    // Tab-focus on any child (e.g. the dismiss button) should behave
    // like a hover — pause, and resume on blur.
    this.element.addEventListener("focusin", this.pause)
    this.element.addEventListener("focusout", this.resume)

    if (this.autoValue && this.delayValue > 0) {
      this.start()
    }
  }

  disconnect() {
    this.clear()
    this.element.removeEventListener("focusin", this.pause)
    this.element.removeEventListener("focusout", this.resume)
  }

  start() {
    this.clear()
    this.startedAt = Date.now()
    this.timer = setTimeout(() => this.dismiss(), this.remaining)
  }

  clear() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  pause = () => {
    if (!this.timer) return
    const elapsed = Date.now() - this.startedAt
    this.remaining = Math.max(0, this.remaining - elapsed)
    this.clear()
  }

  resume = () => {
    if (!this.autoValue) return
    if (this.remaining <= 0) {
      this.dismiss()
      return
    }
    this.start()
  }

  dismiss(event) {
    if (event) event.preventDefault()
    this.clear()
    this.element.setAttribute("data-leaving", "true")
    // After the opacity transition finishes, remove the node entirely
    // so it doesn't push layout around on the empty frame.
    const remove = () => this.element.remove()
    // Matches the `duration-200` class on the component element.
    const fallback = setTimeout(remove, 260)
    this.element.addEventListener("transitionend", () => {
      clearTimeout(fallback)
      remove()
    }, { once: true })
  }
}
