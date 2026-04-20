import { Controller } from "@hotwired/stimulus"

// Accessible dropdown / menu. Pairs with Ui::DropdownComponent.
//
// Markup contract (rendered by the component):
//   <div data-controller="dropdown"
//        data-dropdown-placement-value="bottom_end"
//        data-dropdown-offset-value="8">
//     <div data-dropdown-target="trigger"
//          data-action="click->dropdown#toggle keydown->dropdown#triggerKeydown"
//          aria-haspopup="menu" aria-expanded="false" aria-controls="kc-dropdown-…">
//       … trigger content …
//     </div>
//     <div data-dropdown-target="menu"
//          data-action="keydown->dropdown#menuKeydown"
//          role="menu" hidden>
//       … menu items …
//     </div>
//   </div>
//
// Behavior:
//  • toggle on trigger click
//  • close on Escape / outside click / Turbo navigation
//  • Arrow down/up / Home / End cycle focus through [role=menuitem]
//  • Enter / Space on trigger opens and focuses first item
//  • After close, focus returns to the trigger's first focusable element
//
// The controller never writes copy — all user-facing strings come from
// the server.
export default class extends Controller {
  static targets = ["trigger", "menu"]
  static values = {
    placement: { type: String, default: "bottom_end" },
    offset:    { type: Number, default: 8 }
  }

  connect() {
    // Wire ARIA onto the real interactive child so assistive tech sees
    // haspopup/expanded/controls on the focusable surface — not on the
    // `display: contents` wrapper the component renders.
    const trigger = this.#triggerElement()
    if (trigger) {
      trigger.setAttribute("aria-haspopup", "menu")
      trigger.setAttribute("aria-controls", this.menuTarget.id)
    }

    this.#setExpanded(false)
    this.#setClosedState(true)

    this.outsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.escape = (event) => {
      if (event.key === "Escape" && this.isOpen) {
        event.preventDefault()
        this.close({ restoreFocus: true })
      }
    }
    this.beforeNavigation = () => this.close()

    // Listen globally only while open — bound in #open / detached in #close.
    this.isOpen = false
  }

  disconnect() {
    this.#detachGlobalListeners()
    document.removeEventListener("turbo:before-render", this.beforeNavigation)
    document.removeEventListener("turbo:before-cache", this.beforeNavigation)
  }

  // ---- Actions ----------------------------------------------------------

  toggle(event) {
    event?.preventDefault?.()
    this.isOpen ? this.close({ restoreFocus: true }) : this.open()
  }

  open() {
    if (this.isOpen) return
    this.isOpen = true
    this.menuTarget.hidden = false
    // Two animation frames so the transition runs from the closed state.
    requestAnimationFrame(() => requestAnimationFrame(() => this.#setClosedState(false)))
    this.#setExpanded(true)
    this.#attachGlobalListeners()
    this.#focusFirstItem()
  }

  close({ restoreFocus = false } = {}) {
    if (!this.isOpen) return
    this.isOpen = false
    this.#setClosedState(true)
    this.#setExpanded(false)
    this.#detachGlobalListeners()
    // Delay the `hidden` flip until after the transition so the animation
    // plays. 160ms matches the 150ms duration in the component + a frame.
    this.hideTimeout = window.setTimeout(() => {
      if (!this.isOpen) this.menuTarget.hidden = true
    }, 160)
    if (restoreFocus) this.#focusTrigger()
  }

  triggerKeydown(event) {
    switch (event.key) {
      case "ArrowDown":
      case "Enter":
      case " ":
        event.preventDefault()
        if (!this.isOpen) this.open()
        else this.#focusFirstItem()
        break
      case "ArrowUp":
        event.preventDefault()
        if (!this.isOpen) this.open()
        this.#focusLastItem()
        break
    }
  }

  menuKeydown(event) {
    const items = this.#items()
    if (items.length === 0) return
    const index = items.indexOf(document.activeElement)

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        items[(index + 1 + items.length) % items.length].focus()
        break
      case "ArrowUp":
        event.preventDefault()
        items[(index - 1 + items.length) % items.length].focus()
        break
      case "Home":
        event.preventDefault()
        items[0].focus()
        break
      case "End":
        event.preventDefault()
        items[items.length - 1].focus()
        break
      case "Tab":
        // Let Tab close the menu naturally; focus moves to the next
        // element outside.
        this.close()
        break
    }
  }

  // ---- Helpers ----------------------------------------------------------

  #items() {
    return Array.from(
      this.menuTarget.querySelectorAll('[role="menuitem"]:not([disabled])')
    )
  }

  #focusFirstItem() {
    const [first] = this.#items()
    first?.focus()
  }

  #focusLastItem() {
    const items = this.#items()
    items[items.length - 1]?.focus()
  }

  #triggerElement() {
    return this.triggerTarget.querySelector(
      "button, a, [role='button'], [tabindex]"
    )
  }

  #focusTrigger() {
    const focusable = this.#triggerElement()
    ;(focusable || this.triggerTarget).focus()
  }

  #setExpanded(value) {
    const trigger = this.#triggerElement() || this.triggerTarget
    trigger.setAttribute("aria-expanded", String(value))
  }

  #setClosedState(closed) {
    if (closed) this.menuTarget.setAttribute("data-closed", "")
    else this.menuTarget.removeAttribute("data-closed")
  }

  #attachGlobalListeners() {
    document.addEventListener("click", this.outsideClick, true)
    document.addEventListener("keydown", this.escape)
    document.addEventListener("turbo:before-render", this.beforeNavigation)
    document.addEventListener("turbo:before-cache", this.beforeNavigation)
  }

  #detachGlobalListeners() {
    document.removeEventListener("click", this.outsideClick, true)
    document.removeEventListener("keydown", this.escape)
  }
}
