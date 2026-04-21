import { Controller } from "@hotwired/stimulus"

// Scrolls to the element matching `location.hash` and flashes it with
// a brief ring-plus-glow, then fades back to normal — the StackOverflow
// "focus comment" pattern. Used when a deep-link lands on `/orders#ord_42`
// so the operator's eye snaps to the right card without staring at a
// permanently-tinted row.
//
// Attach to the scroll container (the kanban page or a plain <body>).
// Any descendant with the `.kc-highlightable` class becomes a valid
// target; the controller checks that match before doing anything so
// fragments pointing at non-highlightable IDs (section anchors) are
// left to the browser's default behavior.
//
// Why not rely solely on CSS `:target`?  :target stays matched for as
// long as the fragment is in the URL, so a "flash then fade" via CSS
// animation only plays once per navigation — hitting the same link
// again (or clicking back to the page) won't replay. A small JS
// controller gives us re-triggering on hashchange and graceful
// smooth-scrolling on browsers that ignore `scroll-behavior: smooth`
// for programmatic jumps.
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 2200 }
  }

  connect() {
    this.boundHashChange = this.maybeHighlight.bind(this)
    window.addEventListener("hashchange", this.boundHashChange)
    // Run once on connect — covers both the initial page load and
    // Turbo visits (since connect fires again after each morph).
    this.maybeHighlight()
  }

  disconnect() {
    window.removeEventListener("hashchange", this.boundHashChange)
    clearTimeout(this.clearTimer)
  }

  maybeHighlight() {
    const hash = window.location.hash
    if (!hash || hash.length < 2) return

    const id = hash.slice(1)
    const el = document.getElementById(id)
    if (!el || !el.classList.contains("kc-highlightable")) return

    // Smooth-scroll into view. `block: "center"` keeps the card
    // visually centered rather than pinned against the sticky top bar.
    el.scrollIntoView({ behavior: "smooth", block: "center" })

    // Replay the flash: removing + re-adding the class in separate
    // frames forces the animation to restart even if the element was
    // already flagged from a previous visit.
    el.classList.remove("kc-highlight-flash")
    // eslint-disable-next-line no-unused-expressions
    void el.offsetWidth
    el.classList.add("kc-highlight-flash")

    clearTimeout(this.clearTimer)
    this.clearTimer = setTimeout(() => {
      el.classList.remove("kc-highlight-flash")
    }, this.durationValue)
  }
}
