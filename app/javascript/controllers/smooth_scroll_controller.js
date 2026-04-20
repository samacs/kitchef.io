import { Controller } from "@hotwired/stimulus"

/*
 * Click an anchor with a fragment target and scroll there smoothly,
 * WITHOUT pushing a new history entry or changing `location.hash`.
 * Keeps URLs clean (important for storefront share links — no
 * `?utm=x#menu` tails) while still giving the reader a pleasant
 * motion cue.
 *
 * Usage:
 *   <a href="#menu"
 *      data-controller="smooth-scroll"
 *      data-action="click->smooth-scroll#to">Ver menú</a>
 *
 * The controller reads the target selector from the anchor's own
 * `href` (preferred, keeps no-JS fallbacks working) or from a
 * `data-smooth-scroll-to-value` override when the element isn't an
 * anchor. Falls back to the default browser anchor-jump if the
 * selector doesn't match any node.
 */
export default class extends Controller {
  static values = { to: String }

  to(event) {
    const selector = this.selector()
    if (!selector) return

    const target = document.querySelector(selector)
    if (!target) return

    // Only intercept once we're sure we can fulfill the scroll —
    // that way broken selectors still get the browser default and
    // the user isn't stranded on a dead click.
    event.preventDefault()

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    target.scrollIntoView({
      behavior: reduceMotion ? "auto" : "smooth",
      block: "start"
    })

    // Move focus to the target for a11y. Using preventScroll keeps
    // the smooth-scroll we just started (focus() would otherwise
    // snap the viewport to the target).
    if (target.tabIndex < 0) target.setAttribute("tabindex", "-1")
    target.focus({ preventScroll: true })
  }

  selector() {
    if (this.hasToValue && this.toValue.length > 0) return this.toValue

    const href = this.element.getAttribute("href") || ""
    return href.startsWith("#") && href.length > 1 ? href : null
  }
}
