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

  static values = { slug: String, promotions: { type: Array, default: [] } }

  connect() {
    this.cart = this.load()
    this.tipCents = 0
    this.couponLabel = null
    this.render()
    window.addEventListener("storage", this.onStorageChange)
    document.addEventListener("storefront-cart:clear", this.onClearRequested)
    document.addEventListener("tip-picker:changed", this.onTipChanged)
    document.addEventListener("storefront-coupon:applied", this.onCouponApplied)
    document.addEventListener("storefront-coupon:removed", this.onCouponRemoved)
    document.addEventListener("storefront-cart:request-totals", this.broadcastTotalsListener)
  }

  disconnect() {
    window.removeEventListener("storage", this.onStorageChange)
    document.removeEventListener("storefront-cart:clear", this.onClearRequested)
    document.removeEventListener("tip-picker:changed", this.onTipChanged)
    document.removeEventListener("storefront-coupon:applied", this.onCouponApplied)
    document.removeEventListener("storefront-coupon:removed", this.onCouponRemoved)
    document.removeEventListener("storefront-cart:request-totals", this.broadcastTotalsListener)
  }

  broadcastTotalsListener = () => this.broadcastTotals()

  onTipChanged = (event) => {
    const cents = parseInt(event.detail?.tipCents ?? 0, 10)
    if (Number.isNaN(cents) || cents === this.tipCents) return
    this.tipCents = cents
    this.updateCheckoutSummary()
    this.updatePayload()
    this.broadcastTotals()
  }

  onCouponApplied = (event) => {
    this.couponLabel = event.detail?.label || null
    this.updateCheckoutSummary()
  }

  onCouponRemoved = () => {
    this.couponLabel = null
    this.updateCheckoutSummary()
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

    const existing = this.cart.items.find(i =>
      i.recipe_id === payload.recipe_id && !i.selected_options && !i.removed_components?.length
    )
    if (existing) {
      existing.qty += 1
    } else {
      this.cart.items.push({
        recipe_id: payload.recipe_id,
        recipe_slug: payload.recipe_slug || null,
        name: payload.name,
        price_cents: payload.price_cents,
        category_id: payload.category_id || null,
        lead_time_hours: payload.lead_time_hours || 0,
        photo: payload.photo || null,
        qty: 1,
        notes: ""
      })
    }
    this.save()
    this.render()
    this.openDrawer()
  }

  addWithOptions(event) {
    event.preventDefault()
    const raw = event.params.payload
    if (!raw) return
    let payload
    try {
      payload = typeof raw === "string" ? JSON.parse(raw) : raw
    } catch {
      return
    }

    const optionsCtrl = this.application.getControllerForElementAndIdentifier(
      this.element.querySelector("[data-controller*='storefront-recipe-options']"),
      "storefront-recipe-options"
    )

    let selectedOptions = null
    let removedComponents = []
    let deltaCents = 0

    if (optionsCtrl) {
      selectedOptions = optionsCtrl.selectedOptions()
      removedComponents = optionsCtrl.removedComponents()
      deltaCents = optionsCtrl.totalDeltaCents()
    }

    const hasCustomizations = (selectedOptions && Object.keys(selectedOptions).length > 0) ||
                              removedComponents.length > 0

    this.cart.items.push({
      recipe_id: payload.recipe_id,
      recipe_slug: payload.recipe_slug || null,
      name: payload.name,
      price_cents: payload.price_cents + deltaCents,
      base_price_cents: payload.price_cents,
      category_id: payload.category_id || null,
      lead_time_hours: payload.lead_time_hours || 0,
      photo: payload.photo || null,
      qty: 1,
      notes: "",
      selected_options: hasCustomizations ? selectedOptions : null,
      removed_components: removedComponents.length > 0 ? removedComponents : null
    })

    this.save()
    this.render()
    this.openDrawer()
  }

  increment(event) {
    event.preventDefault()
    const item = this._itemFromEvent(event)
    if (item) {
      item.qty += 1
      this.save()
      this.render()
    }
  }

  decrement(event) {
    event.preventDefault()
    const item = this._itemFromEvent(event)
    if (item && item.qty > 1) {
      item.qty -= 1
      this.save()
      this.render()
    }
  }

  remove(event) {
    event.preventDefault()
    const idx = parseInt(event.currentTarget.dataset.cartIdx, 10)
    if (!isNaN(idx) && idx >= 0 && idx < this.cart.items.length) {
      this.cart.items.splice(idx, 1)
    } else {
      const id = event.currentTarget.dataset.recipeId
      this.cart.items = this.cart.items.filter(i => i.recipe_id !== id)
    }
    this.save()
    this.render()
  }

  _itemFromEvent(event) {
    const idx = parseInt(event.currentTarget.dataset.cartIdx, 10)
    if (!isNaN(idx) && idx >= 0 && idx < this.cart.items.length) {
      return this.cart.items[idx]
    }
    const id = event.currentTarget.dataset.recipeId
    return this.cart.items.find(i => i.recipe_id === id)
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
    this.broadcastTotals()
  }

  broadcastTotals() {
    const subtotal = this.totalCents()
    const tip = this.tipCents || 0
    const discount = this.computeAutoDiscount().cents
    const total = Math.max(subtotal - discount + tip, 0)
    document.dispatchEvent(new CustomEvent("storefront-cart:totals", {
      detail: { subtotalCents: subtotal, discountCents: discount, tipCents: tip, totalCents: total }
    }))
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
      const auto = this.computeAutoDiscount()
      const subtotal = this.totalCents()
      const displayTotal = Math.max(subtotal - auto.cents, 0)
      this.totalTarget.textContent = this.formatMoney(displayTotal)

      const existingDiscount = this.listTarget.parentElement?.querySelector("[data-cart-discount]")
      if (existingDiscount) existingDiscount.remove()

      if (auto.cents > 0 && this.hasFooterTarget) {
        const discountRow = document.createElement("div")
        discountRow.dataset.cartDiscount = "true"
        discountRow.className = "flex items-center justify-between px-4 py-2 -mt-1"
        discountRow.style.color = "var(--brand-1)"
        discountRow.innerHTML = `
          <span class="flex items-center gap-1.5 text-[12px] font-medium">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>
            ${this.escapeHtml(auto.label)}
          </span>
          <span class="font-mono text-[12px] font-medium tabular-nums">−${this.formatMoney(auto.cents)}</span>
        `
        this.footerTarget.insertBefore(discountRow, this.footerTarget.firstChild)
      }
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
      row.className = "border-b border-line py-3 last:border-b-0"

      const customLines = this.summaryCustomLines(item)
      const notes = item.notes
        ? `<div class="mt-1 text-[11.5px] text-ink-2 italic">"${this.escapeHtml(item.notes)}"</div>`
        : ""

      row.innerHTML = `
        <div class="flex items-baseline justify-between gap-3">
          <div class="min-w-0 flex-1">
            <div class="flex items-baseline gap-2">
              <span class="font-mono text-[12px] text-muted shrink-0">${item.qty}×</span>
              <span class="text-[14px] font-medium text-ink truncate">${this.escapeHtml(item.name)}</span>
            </div>
            ${customLines}
            ${notes}
          </div>
          <div class="font-mono text-[13px] text-ink tabular-nums shrink-0">${this.formatMoney(item.price_cents * item.qty)}</div>
        </div>
      `
      this.summaryTarget.appendChild(row)
    })

    const subtotalCents  = this.totalCents()
    const tipCents       = this.tipCents || 0
    const couponLabel    = this.couponLabel || null
    const auto           = this.computeAutoDiscount()
    const discountCents  = auto.cents
    const totalCents     = Math.max(subtotalCents - discountCents + tipCents, 0)

    const breakdown = document.createElement("div")
    breakdown.dataset.cartRow = "true"
    breakdown.className = "mt-4 flex flex-col gap-1.5 border-t border-line pt-3 text-[13px]"

    const subtotalRow = `
      <div class="flex justify-between">
        <span class="text-ink-2">Productos</span>
        <span class="font-mono text-ink tabular-nums">${this.formatMoney(subtotalCents)}</span>
      </div>
    `
    const tipRow = tipCents > 0 ? `
      <div class="flex justify-between">
        <span class="text-ink-2">Propina</span>
        <span class="font-mono text-ink tabular-nums">${this.formatMoney(tipCents)}</span>
      </div>
    ` : ""

    const autoDiscountRow = discountCents > 0 ? `
      <div class="flex justify-between" style="color: var(--brand-1);">
        <span class="flex items-center gap-1.5">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>
          ${this.escapeHtml(auto.label)}
        </span>
        <span class="font-mono font-medium tabular-nums">−${this.formatMoney(discountCents)}</span>
      </div>
    ` : ""

    const couponRow = couponLabel ? `
      <div class="flex justify-between" style="color: var(--brand-1);">
        <span class="flex items-center gap-1.5">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>
          ${this.escapeHtml(couponLabel)}
        </span>
        <span class="font-mono font-medium tabular-nums">Aplicado</span>
      </div>
    ` : ""

    breakdown.innerHTML = subtotalRow + autoDiscountRow + couponRow + tipRow
    this.summaryTarget.appendChild(breakdown)

    const total = document.createElement("div")
    total.dataset.cartRow = "true"
    total.className = "mt-3 flex items-baseline justify-between border-t border-line pt-3"
    total.innerHTML = `
      <span class="text-[14px] font-semibold text-ink">Total</span>
      <span class="font-serif text-[24px] tracking-tight text-ink tabular-nums">${this.formatMoney(totalCents)}</span>
    `
    this.summaryTarget.appendChild(total)
  }

  summaryCustomLines(item) {
    let html = ""
    if (item.selected_options) {
      Object.values(item.selected_options).forEach(selections => {
        const labels = Array.isArray(selections)
          ? selections.map(s => this.escapeHtml(s.label || s.text || "")).filter(Boolean).join(" · ")
          : ""
        if (labels) {
          html += `<div class="mt-1 ml-6 text-[11.5px] text-ink-2">${labels}</div>`
        }
      })
    }
    if (item.removed_components?.length) {
      const removed = item.removed_components.map(c => `sin ${this.escapeHtml(c)}`).join(" · ")
      html += `<div class="mt-0.5 ml-6 text-[11.5px] text-muted italic">${removed}</div>`
    }
    return html
  }

  updatePayload() {
    if (!this.hasPayloadTarget) return
    this.payloadTarget.value = JSON.stringify({
      items: this.cart.items.map(i => {
        const item = {
          recipe_id: i.recipe_id,
          quantity:  i.qty,
          notes:     i.notes || ""
        }
        if (i.selected_options) item.selected_options = i.selected_options
        if (i.removed_components?.length) item.removed_components = i.removed_components
        return item
      })
    })
  }

  rowHtml(item) {
    const photo = item.photo
      ? `<img src="${this.escapeAttr(item.photo)}" class="h-[56px] w-[56px] rounded-[8px] object-cover" alt="">`
      : `<div class="h-[56px] w-[56px] rounded-[8px]" style="background: var(--brand-1-soft);"></div>`

    let customLines = ""
    if (item.selected_options) {
      Object.values(item.selected_options).forEach(selections => {
        const labels = Array.isArray(selections)
          ? selections.map(s => this.escapeHtml(s.label || s.text || "")).filter(Boolean).join(", ")
          : ""
        if (labels) customLines += `<div class="text-[11px] text-muted truncate">${labels}</div>`
      })
    }
    if (item.removed_components?.length) {
      const removed = item.removed_components.map(c => `sin ${this.escapeHtml(c)}`).join(", ")
      customLines += `<div class="text-[11px] text-muted italic truncate">${removed}</div>`
    }

    const idx = this.cart.items.indexOf(item)
    return `
      ${photo}
      <div class="min-w-0 flex-1">
        <div class="flex items-start justify-between gap-2">
          <div class="text-[14px] font-semibold text-ink truncate">${this.escapeHtml(item.name)}</div>
          <div class="shrink-0 font-serif text-[16px] text-ink">${this.formatMoney(item.price_cents * item.qty)}</div>
        </div>
        ${customLines}
        <div class="mt-2 flex items-center justify-between">
          <div class="inline-flex items-center overflow-hidden rounded-full border border-line">
            <button type="button" class="h-7 w-7 text-ink-2 hover:bg-bg" data-action="click->storefront-cart#decrement" data-cart-idx="${idx}" data-recipe-id="${this.escapeAttr(item.recipe_id)}" aria-label="Menos">−</button>
            <span class="min-w-[26px] text-center font-mono text-[13px]">${item.qty}</span>
            <button type="button" class="h-7 w-7 text-ink-2 hover:bg-bg" data-action="click->storefront-cart#increment" data-cart-idx="${idx}" data-recipe-id="${this.escapeAttr(item.recipe_id)}" aria-label="Más">+</button>
          </div>
          <div class="flex items-center gap-3">
            ${item.recipe_slug && (item.selected_options || item.removed_components?.length) ? `<button type="button" class="text-[11.5px] font-medium hover:underline" style="color: var(--brand-1);" data-controller="storefront-customize-trigger" data-action="click->storefront-customize-trigger#edit" data-recipe-slug="${this.escapeAttr(item.recipe_slug)}" data-cart-idx="${idx}">Editar</button>` : ""}
            <button type="button" class="text-[11.5px] text-muted hover:text-err" data-action="click->storefront-cart#remove" data-cart-idx="${idx}" data-recipe-id="${this.escapeAttr(item.recipe_id)}">Quitar</button>
          </div>
        </div>
      </div>
    `
  }

  // ── Auto-promotion discount ──────────────────────────────────────────

  computeAutoDiscount() {
    const promos = this.promotionsValue || []
    if (!promos.length || !this.cart.items.length) return { cents: 0, label: null }

    let bestCents = 0
    let bestLabel = null

    for (const promo of promos) {
      const cents = this.computePromoDiscount(promo)
      if (cents > bestCents) {
        bestCents = cents
        bestLabel = promo.label
      }
    }

    return { cents: bestCents, label: bestLabel }
  }

  computePromoDiscount(promo) {
    const qualifying = this.qualifyingItems(promo)
    const subtotal = this.totalCents()

    if (promo.discount_type === "percentage") {
      const base = qualifying.reduce((s, i) => s + i.price_cents * i.qty, 0)
      let discount = Math.floor(base * promo.discount_value / 100)
      if (promo.max_discount_cents) discount = Math.min(discount, promo.max_discount_cents)
      return Math.min(discount, subtotal)
    }

    if (promo.discount_type === "fixed_amount") {
      if (promo.scope_type === "order") return Math.min(promo.discount_value, subtotal)
      return qualifying.length > 0 ? Math.min(promo.discount_value, subtotal) : 0
    }

    if (promo.discount_type === "bogo") {
      const buy = promo.bogo_buy || 1
      const get = promo.bogo_get || 1
      const cycle = buy + get
      let total = 0
      for (const item of qualifying) {
        const qty = item.qty
        if (qty >= cycle) {
          const freeUnits = Math.floor(qty / cycle) * get
          total += freeUnits * item.price_cents
        }
      }
      return Math.min(total, subtotal)
    }

    return 0
  }

  qualifyingItems(promo) {
    if (promo.scope_type === "order") return this.cart.items
    if (promo.scope_type === "recipe") {
      const ids = new Set(promo.recipe_ids || [])
      return this.cart.items.filter(i => ids.has(i.recipe_id))
    }
    if (promo.scope_type === "category") {
      const ids = new Set(promo.category_ids || [])
      return this.cart.items.filter(i => ids.has(i.category_id))
    }
    return []
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
