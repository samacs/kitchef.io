import { Controller } from "@hotwired/stimulus"

// Progressive-enhancement reveal. Keeps the `line-clamp-3` truncation
// for content that actually overflows and shows a "Ver más" / "Ver
// menos" toggle; content that fits in the clamp box leaves the toggle
// hidden so short descriptions never get a useless chevron.
//
// The decision is made on connect by comparing the clamped element's
// scrollHeight to its clientHeight — a `> 1` pixel delta means the
// clamp is hiding text. We also re-check on resize because a narrower
// viewport can turn a fitting line into an overflowing one.
//
// Classes are data-driven so the component template stays in charge of
// the exact Tailwind utility used to truncate.
export default class extends Controller {
  static targets = ["content", "toggle", "label", "chevron"]
  static classes = ["collapsed", "expanded"]

  connect() {
    this.expanded = false
    this.maybeShowToggle()

    this.onResize = this.maybeShowToggle.bind(this)
    window.addEventListener("resize", this.onResize)
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
  }

  maybeShowToggle() {
    if (!this.hasContentTarget || !this.hasToggleTarget) return

    // Only reveal the toggle when there's truly hidden content. A 1px
    // fudge accounts for sub-pixel rounding across browsers.
    const overflowing = this.contentTarget.scrollHeight - this.contentTarget.clientHeight > 1
    this.toggleTarget.hidden = !overflowing && !this.expanded
  }

  toggle(event) {
    event.preventDefault()
    this.expanded = !this.expanded

    this.contentTarget.classList.toggle(this.collapsedClass, !this.expanded)
    this.contentTarget.classList.toggle(this.expandedClass, this.expanded)

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.expanded
        ? this.toggleTarget.dataset.labelLess
        : this.toggleTarget.dataset.labelMore
    }

    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("rotate-180", this.expanded)
    }
  }
}
