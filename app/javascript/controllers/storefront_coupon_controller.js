import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "feedback", "hidden", "badge"]
  static values = { url: String }

  connect() {
    this.validated = false
    this.discountLabel = null
  }

  async apply(event) {
    event?.preventDefault()
    const code = this.inputTarget.value.trim().toUpperCase()
    if (!code) return

    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = "…"

    try {
      const subtotal = this.currentSubtotal()
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        },
        body: JSON.stringify({ code, subtotal_cents: subtotal })
      })

      const data = await response.json()

      if (data.valid) {
        this.validated = true
        this.discountLabel = data.label
        this.hiddenTarget.value = code
        this.showSuccess(data.label)
        document.dispatchEvent(new CustomEvent("storefront-coupon:applied", {
          detail: { code, label: data.label }
        }))
      } else {
        this.validated = false
        this.hiddenTarget.value = ""
        this.showError(data.error)
        document.dispatchEvent(new CustomEvent("storefront-coupon:removed"))
      }
    } catch {
      this.showError("Error de conexión")
    } finally {
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = this.buttonTarget.dataset.label
    }
  }

  clear(event) {
    event?.preventDefault()
    this.inputTarget.value = ""
    this.hiddenTarget.value = ""
    this.validated = false
    this.discountLabel = null
    this.feedbackTarget.innerHTML = ""
    this.feedbackTarget.hidden = true
    if (this.hasBadgeTarget) this.badgeTarget.hidden = true
    document.dispatchEvent(new CustomEvent("storefront-coupon:removed"))
  }

  showSuccess(label) {
    this.feedbackTarget.hidden = false
    this.feedbackTarget.innerHTML = `
      <div class="flex items-center justify-between gap-2 rounded-[10px] p-3 border"
           style="background: var(--brand-1-soft); border-color: var(--brand-1); border-opacity: 0.3;">
        <div class="flex items-center gap-2">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" style="color: var(--brand-1);" aria-hidden="true">
            <path d="M20 6L9 17l-5-5"/>
          </svg>
          <span class="text-[13px] font-medium" style="color: var(--brand-1);">${this.escapeHtml(label)}</span>
        </div>
        <button type="button" class="text-[12px] font-medium hover:underline" style="color: var(--brand-1);"
                data-action="click->storefront-coupon#clear">Quitar</button>
      </div>
    `
    this.inputTarget.disabled = true
  }

  showError(message) {
    this.feedbackTarget.hidden = false
    this.feedbackTarget.innerHTML = `
      <p class="text-[12.5px] text-err font-medium">${this.escapeHtml(message)}</p>
    `
  }

  currentSubtotal() {
    try {
      const raw = sessionStorage.getItem(this.storageKey)
      if (!raw) return 0
      const cart = JSON.parse(raw)
      return (cart.items || []).reduce((sum, i) => sum + (i.price_cents * i.qty), 0)
    } catch { return 0 }
  }

  get storageKey() {
    const slug = document.querySelector("[data-storefront-cart-slug-value]")?.dataset.storefrontCartSlugValue
    return slug ? `kitchef_sf_cart_${slug}` : "kitchef_sf_cart"
  }

  escapeHtml(str) {
    return String(str || "").replace(/[&<>"']/g, c => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[c])
  }
}
