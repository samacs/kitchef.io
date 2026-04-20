import { Controller } from "@hotwired/stimulus"

// Slide-in drawer with backdrop. Pairs with Nav::DashboardDrawerComponent.
//
// Markup contract (rendered by the component):
//   <div data-controller="drawer" class="contents">
//     <div data-drawer-target="backdrop"
//          data-action="click->drawer#close"
//          aria-hidden="true" hidden>…</div>
//     <aside data-drawer-target="panel"
//            role="dialog" aria-modal="true"
//            data-action="keydown->drawer#keydown"
//            hidden>
//       … drawer contents …
//     </aside>
//     <!-- triggers live anywhere in the same controller scope -->
//     <button data-action="click->drawer#open">☰</button>
//   </div>
//
// Behavior:
//  • open on trigger click
//  • close on backdrop click / Escape / Turbo navigation / in-panel close button
//  • lock page scroll while open (body overflow=hidden, no layout shift
//    because the page scrollbar gutter is padded)
//  • auto-focus the first focusable element in the panel on open; trap
//    Tab inside the panel so focus never escapes behind the backdrop
//  • restore focus to the trigger when closed with Escape
//
// The drawer is intentionally position:fixed so it escapes any
// backdrop-filter ancestor stacking context. The host layout must render
// the drawer OUTSIDE the sticky, blurred top-bar subtree — see
// panel.html.erb for the correct nesting.
export default class extends Controller {
  static targets = ["backdrop", "panel"]

  connect() {
    this.isOpen = false

    this.escape = (event) => {
      if (event.key === "Escape" && this.isOpen) {
        event.preventDefault()
        this.close({ restoreFocus: true })
      }
    }
    this.beforeNavigation = () => this.close()
  }

  disconnect() {
    if (this.hideTimeout) window.clearTimeout(this.hideTimeout)
    this.#unlockScroll()
    this.#detachGlobalListeners()
    document.removeEventListener("turbo:before-render", this.beforeNavigation)
    document.removeEventListener("turbo:before-cache", this.beforeNavigation)
  }

  // ---- Actions ----------------------------------------------------------

  open(event) {
    event?.preventDefault?.()
    if (this.isOpen) return
    this.lastTrigger = event?.currentTarget || null
    this.isOpen = true

    this.backdropTarget.hidden = false
    this.panelTarget.hidden = false
    // Two frames so the transition runs from the closed state. Without
    // this, the initial render already has translate-x-0 and the
    // slide-in animation is invisible.
    requestAnimationFrame(() => requestAnimationFrame(() => {
      this.backdropTarget.dataset.open = ""
      this.panelTarget.dataset.open = ""
    }))

    this.panelTarget.setAttribute("aria-hidden", "false")
    this.#lockScroll()
    this.#attachGlobalListeners()
    this.#focusFirst()
  }

  close({ restoreFocus = false } = {}) {
    if (!this.isOpen) return
    this.isOpen = false

    delete this.backdropTarget.dataset.open
    delete this.panelTarget.dataset.open
    this.panelTarget.setAttribute("aria-hidden", "true")

    this.#detachGlobalListeners()
    this.#unlockScroll()

    // Flip `hidden` after the slide-out completes so the panel is fully
    // removed from the tab order. 260ms > the 250ms CSS transition.
    this.hideTimeout = window.setTimeout(() => {
      if (!this.isOpen) {
        this.backdropTarget.hidden = true
        this.panelTarget.hidden = true
      }
    }, 260)

    if (restoreFocus) this.lastTrigger?.focus?.()
  }

  keydown(event) {
    if (event.key !== "Tab") return

    const items = this.#focusables()
    if (items.length === 0) return

    const first = items[0]
    const last = items[items.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  // ---- Helpers ----------------------------------------------------------

  #focusables() {
    return Array.from(this.panelTarget.querySelectorAll(
      'a[href], button:not([disabled]), input:not([disabled]), ' +
      '[tabindex]:not([tabindex="-1"])'
    )).filter(el => !el.hasAttribute("disabled") && !el.hidden)
  }

  #focusFirst() {
    const [first] = this.#focusables()
    first?.focus()
  }

  #lockScroll() {
    // Preserve the current scrollbar gutter so the page doesn't jump
    // when we remove the scrollbar via overflow:hidden.
    const scrollbarW = window.innerWidth - document.documentElement.clientWidth
    this.previousBodyOverflow = document.body.style.overflow
    this.previousBodyPadding  = document.body.style.paddingRight
    document.body.style.overflow = "hidden"
    if (scrollbarW > 0) document.body.style.paddingRight = `${scrollbarW}px`
  }

  #unlockScroll() {
    if (this.previousBodyOverflow !== undefined) {
      document.body.style.overflow = this.previousBodyOverflow
      document.body.style.paddingRight = this.previousBodyPadding
      this.previousBodyOverflow = undefined
    }
  }

  #attachGlobalListeners() {
    document.addEventListener("keydown", this.escape)
    document.addEventListener("turbo:before-render", this.beforeNavigation)
    document.addEventListener("turbo:before-cache", this.beforeNavigation)
  }

  #detachGlobalListeners() {
    document.removeEventListener("keydown", this.escape)
  }
}
