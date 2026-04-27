import { Controller } from "@hotwired/stimulus"

// Storefront menu-card + dish-detail photo carousel.
//
// CSS does the heavy lifting (`scroll-snap-type: x mandatory`),
// so this controller only handles:
//   1. Prev/next arrow clicks → smooth-scroll the track by one slide
//   2. The dot indicator + thumb-strip `data-active` flags, repainted
//      from the track's scrollLeft on the native `scroll` event
//   3. Keyboard arrow navigation when the track has focus
//   4. (when rendered with_thumbs) `goTo` action invoked by thumb
//      clicks that scrolls the carousel to a specific slide index
//
// The track is `tabindex="0"` so keyboard users can land on it.
export default class extends Controller {
  static targets = ["track", "slide", "prev", "next", "dot", "thumb"]

  connect() {
    this.trackTarget.addEventListener("keydown", this.#onKeydown)
    this.#repaintIndicators()
  }

  disconnect() {
    this.trackTarget.removeEventListener("keydown", this.#onKeydown)
  }

  prev() {
    this.#scrollBy(-1)
  }

  next() {
    this.#scrollBy(+1)
  }

  // Thumb strip → scroll the carousel to the clicked slide index.
  // Stimulus reads the index from `data-photo-carousel-index-param`.
  goTo(event) {
    event?.preventDefault()
    const index = Number(event.params?.index ?? 0)
    if (Number.isNaN(index)) return
    const slideWidth = this.slideTargets[0]?.clientWidth || this.trackTarget.clientWidth
    this.trackTarget.scrollTo({ left: index * slideWidth, behavior: "smooth" })
  }

  updateActive() {
    if (this.scrollFrame) cancelAnimationFrame(this.scrollFrame)
    this.scrollFrame = requestAnimationFrame(() => this.#repaintIndicators())
  }

  // ── Internals ─────────────────────────────────────────────────────

  #scrollBy(direction) {
    const slideWidth = this.slideTargets[0]?.clientWidth || this.trackTarget.clientWidth
    this.trackTarget.scrollBy({ left: direction * slideWidth, behavior: "smooth" })
  }

  #repaintIndicators() {
    const idx = this.#activeIndex()
    this.dotTargets.forEach((dot, i) => {
      dot.dataset.active = i === idx ? "true" : "false"
    })
    this.thumbTargets.forEach((thumb, i) => {
      thumb.dataset.active = i === idx ? "true" : "false"
    })
  }

  #activeIndex() {
    const slideWidth = this.slideTargets[0]?.clientWidth || 1
    return Math.round(this.trackTarget.scrollLeft / slideWidth)
  }

  #onKeydown = (event) => {
    if (event.key === "ArrowLeft")  { event.preventDefault(); this.prev() }
    if (event.key === "ArrowRight") { event.preventDefault(); this.next() }
  }
}
