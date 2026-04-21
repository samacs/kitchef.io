import { Controller } from "@hotwired/stimulus"

// Autocomplete client picker for the order form. Hits a server endpoint
// (defaults to /clients/search?q=...) and renders the returned HTML
// directly into a popover. Supports keyboard navigation (Up/Down/Enter)
// and an inline "+ nuevo cliente" disclosure that POSTs a fresh client
// inline and pre-selects it.
export default class extends Controller {
  static targets = [
    "input", "hidden", "results", "inlinePanel",
    "firstName", "lastName", "phone", "colonia", "inlineError"
  ]

  static values = {
    searchUrl: String
  }

  connect() {
    this.timeout = null
    this.activeIndex = -1
    document.addEventListener("click", this.handleOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
    if (this.timeout) clearTimeout(this.timeout)
  }

  handleOutsideClick = (event) => {
    if (!this.element.contains(event.target)) this.hideResults()
  }

  search() {
    if (this.timeout) clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.performSearch(), 180)
  }

  async performSearch() {
    const q = this.inputTarget.value.trim()
    const url = `${this.searchUrlValue}?q=${encodeURIComponent(q)}`
    try {
      const res = await fetch(url, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" }
      })
      if (!res.ok) return
      const html = await res.text()
      this.resultsTarget.innerHTML = html
      this.showResults()
      this.activeIndex = -1
    } catch (_e) {
      // Network errors are non-fatal — leave the dropdown closed.
    }
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden")
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden")
  }

  pick(event) {
    const button = event.target.closest("button[data-client-id]")
    if (!button) return
    event.preventDefault()
    this.selectClient(button.dataset.clientId, button.dataset.clientName, {
      colonia:        button.dataset.clientColonia,
      city:           button.dataset.clientCity,
      streetAddress:  button.dataset.clientStreetAddress
    })
    this.hideResults()
  }

  selectClient(id, name, shipping = {}) {
    this.hiddenTarget.value = id
    this.inputTarget.value = name
    this.autofillShipping(shipping)
  }

  // Pre-fill empty shipping inputs on the order form with whatever the
  // selected client already has on file. We never overwrite a value the
  // operator already typed — she may be sending the pedido to a different
  // address (office, gift, event).
  autofillShipping({ colonia, city, streetAddress } = {}) {
    this.fillIfEmpty("order_colonia", colonia)
    this.fillIfEmpty("order_city", city)
    this.fillIfEmpty("order_delivery_address", streetAddress)
  }

  fillIfEmpty(inputId, value) {
    if (!value) return
    const input = document.getElementById(inputId)
    if (!input) return
    if (input.value && input.value.trim().length > 0) return
    input.value = value
  }

  keydown(event) {
    if (this.resultsTarget.classList.contains("hidden")) return
    const items = Array.from(this.resultsTarget.querySelectorAll("button[data-client-id]"))
    if (items.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, items.length - 1)
      this.highlight(items)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlight(items)
    } else if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      const button = items[this.activeIndex]
      // Mirror the mouse-click path: pass the same shipping dataset so
      // keyboard selection also autofills colonia/city/address. Without
      // this the hidden id updates but the address fields stay blank.
      this.selectClient(button.dataset.clientId, button.dataset.clientName, {
        colonia:       button.dataset.clientColonia,
        city:          button.dataset.clientCity,
        streetAddress: button.dataset.clientStreetAddress
      })
      this.hideResults()
    } else if (event.key === "Escape") {
      this.hideResults()
    }
  }

  highlight(items) {
    items.forEach((it, idx) => {
      it.classList.toggle("bg-bg-2/60", idx === this.activeIndex)
    })
    items[this.activeIndex]?.scrollIntoView({ block: "nearest" })
  }

  openInline(event) {
    event.preventDefault()
    this.inlinePanelTarget.classList.remove("hidden")
    this.firstNameTarget?.focus()
  }

  closeInline(event) {
    event.preventDefault()
    this.inlinePanelTarget.classList.add("hidden")
    this.inlineErrorTarget?.classList.add("hidden")
  }

  async submitInline(event) {
    event.preventDefault()
    const data = new FormData()
    data.append("client[first_name]", this.firstNameTarget.value)
    data.append("client[last_name]",  this.lastNameTarget.value)
    data.append("client[phone]",      this.phoneTarget.value)
    data.append("client[colonia]",    this.coloniaTarget.value)

    const csrf = document.querySelector("meta[name='csrf-token']")?.content
    try {
      const res = await fetch("/clients.json", {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": csrf },
        body: data
      })

      if (res.ok) {
        const payload = await res.json()
        this.selectClient(payload.id, payload.name, {
          colonia:       payload.colonia,
          city:          payload.city,
          streetAddress: payload.street_address
        })
        this.inlinePanelTarget.classList.add("hidden")
        this.inlineErrorTarget?.classList.add("hidden")
        this.firstNameTarget.value = ""
        this.lastNameTarget.value = ""
        this.phoneTarget.value = ""
        this.coloniaTarget.value = ""
      } else {
        const payload = await res.json().catch(() => ({}))
        const messages = (payload?.errors || []).join(" · ")
        if (this.hasInlineErrorTarget) {
          this.inlineErrorTarget.textContent = messages || "Revisa los datos."
          this.inlineErrorTarget.classList.remove("hidden")
        }
      }
    } catch (_e) {
      if (this.hasInlineErrorTarget) {
        this.inlineErrorTarget.textContent = "No pudimos guardar al cliente. Inténtalo de nuevo."
        this.inlineErrorTarget.classList.remove("hidden")
      }
    }
  }
}
