import { Controller } from "@hotwired/stimulus"

/*
 * Storefront cart — entirely client-side state. Keyed by storefront slug
 * in sessionStorage so:
 *   - A page reload keeps the cart (the customer didn't lose her progress).
 *   - Different kitchens in different tabs don't share carts.
 *   - Closing the tab wipes it (no lingering stale state).
 *
 * Prices in sessionStorage are the price-at-add-time; the server
 * re-snapshots authoritative prices from Account.recipes in Orders::Place
 * so a tampered localStorage never changes what the operator is paid.
 *
 * Targets (all optional — different pages expose different slices):
 *   - badge:     cart-count badge on the header button
 *   - backdrop:  drawer backdrop (fixed, z-190)
 *   - panel:     drawer panel (fixed, z-200, translate-x-full when closed)
 *   - list:      drawer item list
 *   - emptyState:"Tu carrito está vacío" block
 *   - footer:    drawer footer (totals + checkout CTA)
 *   - total:     drawer grand total
 *   - summary:   checkout-page cart recap container
 *   - summaryEmpty: empty-cart placeholder on checkout page
 *   - payload:   hidden input that carries the serialized cart on submit
 */
export default class extends Controller {
  static targets = [
    "badge", "backdrop", "panel", "list", "emptyState",
    "footer", "total", "summary", "summaryEmpty", "payload", "submit"
  ]

  static values = { slug: String }

  connect() {
    this.cart = this.load()
    this.render()
    window.addEventListener("storage", this.onStorageChange)
    // Any page can dispatch `storefront-cart:clear` to wipe the cart
    // (used by the confirmation page — once the order is placed, the
    // customer shouldn't see her just-paid items lingering in the
    // header badge). Dispatched on `document` so the sender doesn't
    // need to know where the controller is mounted.
    document.addEventListener("storefront-cart:clear", this.onClearRequested)
  }

  disconnect() {
    window.removeEventListener("storage", this.onStorageChange)
    document.removeEventListener("storefront-cart:clear", this.onClearRequested)
  }

  // ── Key ─────────────────────────────────────────────────────────────

  get storageKey() {
    return `kitchef_sf_cart_${this.slugValue}`
  }

  // ── Persistence ─────────────────────────────────────────────────────

  load() {
    try {
      const raw = sessionStorage.getItem(this.storageKey)
      if (!raw) return { items: [] }
      const parsed = JSON.parse(raw)
      return parsed && Array.isArray(parsed.items) ? parsed : { items: [] }
    } catch {
      return { items: [] }
    }
  }

  save() {
    try {
      sessionStorage.setItem(this.storageKey, JSON.stringify(this.cart))
    } catch {
      // sessionStorage full or unavailable — silent fail (the cart's
      // in-memory state still works for this tab).
    }
  }

  onStorageChange = (event) => {
    if (event.key === this.storageKey) {
      this.cart = this.load()
      this.render()
    }
  }

  onClearRequested = () => {
    this.cart = { items: [] }
    this.save()
    this.render()
    this.closeDrawer()
  }

  // ── Actions ─────────────────────────────────────────────────────────

  add(event) {
    event.preventDefault()
    const raw = event.params.payload
    if (!raw) return
    let payload
    try {
      payload = typeof raw === "string" ? JSON.parse(raw) : raw
    } catch {
      return
    }

    const existing = this.cart.items.find(i => i.recipe_id === payload.recipe_id)
    if (existing) {
      existing.qty += 1
    } else {
      this.cart.items.push({
        recipe_id: payload.recipe_id,
        name: payload.name,
        price_cents: payload.price_cents,
        photo: payload.photo || null,
        qty: 1,
        notes: ""
      })
    }
    this.save()
    this.render()
    this.openDrawer()
  }

  increment(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.recipeId
    const item = this.cart.items.find(i => i.recipe_id === id)
    if (item) {
      item.qty += 1
      this.save()
      this.render()
    }
  }

  decrement(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.recipeId
    const item = this.cart.items.find(i => i.recipe_id === id)
    if (item && item.qty > 1) {
      item.qty -= 1
      this.save()
      this.render()
    }
  }

  remove(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.recipeId
    this.cart.items = this.cart.items.filter(i => i.recipe_id !== id)
    this.save()
    this.render()
  }

  openDrawer(event) {
    if (event) event.preventDefault()
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
      // Allow the next frame to pick up the `hidden` removal before
      // starting the transform transition.
      requestAnimationFrame(() => {
        this.panelTarget.classList.remove("translate-x-full")
      })
    }
  }

  closeDrawer(event) {
    if (event) event.preventDefault()
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("translate-x-full")
      // Hide the backdrop after the panel finishes sliding out.
      setTimeout(() => {
        if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
      }, 300)
    }
  }

  checkout(event) {
    // Ensure the hidden payload input on the checkout form is populated
    // before navigation. The `new` page's form also has its own cart
    // controller that re-renders on connect, but this is a safety rail
    // for the drawer's direct-link case.
    this.updatePayload()
  }

  // ── Render ──────────────────────────────────────────────────────────

  render() {
    this.updateBadge()
    this.updateDrawer()
    this.updateCheckoutSummary()
    this.updatePayload()
    this.updateSubmit()
  }

  // Checkout form submit button — disabled whenever the cart is empty
  // OR the kitchen's schedule is closed (server-rendered via the
  // `data-schedule-closed` attribute). The server-side Orders::Place
  // also blocks both conditions, but client-side disable turns the UX
  // from "click, see error" to "can't click yet."
  updateSubmit() {
    if (!this.hasSubmitTarget) return
    const empty          = this.cart.items.length === 0
    const scheduleClosed = this.submitTarget.dataset.scheduleClosed === "true"
    const disabled       = empty || scheduleClosed
    this.submitTarget.disabled = disabled
    this.submitTarget.classList.toggle("opacity-50", disabled)
    this.submitTarget.classList.toggle("cursor-not-allowed", disabled)
  }

  totalCents() {
    return this.cart.items.reduce((sum, i) => sum + i.price_cents * i.qty, 0)
  }

  count() {
    return this.cart.items.reduce((sum, i) => sum + i.qty, 0)
  }

  updateBadge() {
    if (!this.hasBadgeTarget) return
    const n = this.count()
    this.badgeTarget.dataset.count = n
    this.badgeTarget.textContent = n
    this.badgeTarget.style.display = n > 0 ? "inline-flex" : "none"
  }

  updateDrawer() {
    if (!this.hasListTarget) return

    // Leave the empty-state block inside list so we can hide/show it;
    // everything else gets re-rendered each update.
    this.listTarget.querySelectorAll("[data-cart-row]").forEach(el => el.remove())

    if (this.cart.items.length === 0) {
      if (this.hasEmptyStateTarget) this.emptyStateTarget.style.display = ""
      if (this.hasFooterTarget) this.footerTarget.hidden = true
      return
    }

    if (this.hasEmptyStateTarget) this.emptyStateTarget.style.display = "none"
    if (this.hasFooterTarget) this.footerTarget.hidden = false

    this.cart.items.forEach(item => {
      const row = document.createElement("div")
      row.dataset.cartRow = "true"
      row.className = "mb-3 flex gap-3 rounded-[12px] border border-line bg-surface p-3"
      row.innerHTML = this.rowHtml(item)
      this.listTarget.appendChild(row)
    })

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = this.formatMoney(this.totalCents())
    }
  }

  updateCheckoutSummary() {
    if (!this.hasSummaryTarget) return

    this.summaryTarget.querySelectorAll("[data-cart-row]").forEach(el => el.remove())

    if (this.cart.items.length === 0) {
      if (this.hasSummaryEmptyTarget) this.summaryEmptyTarget.style.display = ""
      return
    }

    if (this.hasSummaryEmptyTarget) this.summaryEmptyTarget.style.display = "none"

    this.cart.items.forEach(item => {
      const row = document.createElement("div")
      row.dataset.cartRow = "true"
      row.className = "flex items-center justify-between border-b border-line py-3 last:border-b-0"
      row.innerHTML = `
        <div class="min-w-0">
          <div class="text-[14px] font-semibold text-ink truncate">${this.escapeHtml(item.name)}</div>
          <div class="font-mono text-[11.5px] text-muted">× ${item.qty}</div>
        </div>
        <div class="font-mono text-[13px] text-ink">${this.formatMoney(item.price_cents * item.qty)}</div>
      `
      this.summaryTarget.appendChild(row)
    })

    const total = document.createElement("div")
    total.dataset.cartRow = "true"
    total.className = "mt-4 flex items-baseline justify-between border-t border-line pt-4"
    total.innerHTML = `
      <span class="text-[14px] font-semibold text-ink">Total</span>
      <span class="font-serif text-[24px] tracking-tight text-ink">${this.formatMoney(this.totalCents())}</span>
    `
    this.summaryTarget.appendChild(total)
  }

  updatePayload() {
    if (!this.hasPayloadTarget) return
    // Serialize items for the server. Order matters for a deterministic
    // line-item order; the command re-reads prices from the DB so the
    // price_cents in here is advisory only.
    this.payloadTarget.value = JSON.stringify({
      items: this.cart.items.map(i => ({
        recipe_id: i.recipe_id,
        quantity:  i.qty,
        notes:     i.notes || ""
      }))
    })
  }

  rowHtml(item) {
    const photo = item.photo
      ? `<img src="${this.escapeAttr(item.photo)}" class="h-[56px] w-[56px] rounded-[8px] object-cover" alt="">`
      : `<div class="h-[56px] w-[56px] rounded-[8px]" style="background: var(--brand-1-soft);"></div>`
    return `
      ${photo}
      <div class="min-w-0 flex-1">
        <div class="flex items-start justify-between gap-2">
          <div class="text-[14px] font-semibold text-ink truncate">${this.escapeHtml(item.name)}</div>
          <div class="shrink-0 font-serif text-[16px] text-ink">${this.formatMoney(item.price_cents * item.qty)}</div>
        </div>
        <div class="mt-2 flex items-center justify-between">
          <div class="inline-flex items-center overflow-hidden rounded-full border border-line">
            <button type="button" class="h-7 w-7 text-ink-2 hover:bg-bg" data-action="click->storefront-cart#decrement" data-recipe-id="${this.escapeAttr(item.recipe_id)}" aria-label="Menos">−</button>
            <span class="min-w-[26px] text-center font-mono text-[13px]">${item.qty}</span>
            <button type="button" class="h-7 w-7 text-ink-2 hover:bg-bg" data-action="click->storefront-cart#increment" data-recipe-id="${this.escapeAttr(item.recipe_id)}" aria-label="Más">+</button>
          </div>
          <button type="button" class="text-[11.5px] text-muted hover:text-err" data-action="click->storefront-cart#remove" data-recipe-id="${this.escapeAttr(item.recipe_id)}">Quitar</button>
        </div>
      </div>
    `
  }

  // ── Utils ───────────────────────────────────────────────────────────

  formatMoney(cents) {
    const pesos = cents / 100
    return `$${pesos.toLocaleString("es-MX", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  escapeHtml(str) {
    return String(str || "").replace(/[&<>"']/g, c => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[c])
  }

  escapeAttr(str) {
    return this.escapeHtml(str)
  }
}
