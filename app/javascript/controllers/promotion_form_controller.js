import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "kindRadio",
    "codeSection",
    "discountTypeRadio",
    "valuePctWrap",
    "valueFixedWrap",
    "valuePctInput",
    "valueFixedInput",
    "bogoSection",
    "maxDiscountSection",
    "scopeTypeRadio",
    "recipesSection",
    "categoriesSection",
    "validityModeRadio",
    "dateRangeSection",
    "weekdaysSection",
    "badgeLabelInput",
    "badgeColorInput",
    "previewCard",
    "previewPhoto",
    "previewPhotoFallback",
    "previewLabel",
    "previewBadge",
    "previewName",
    "previewPrice",
    "previewNav",
    "previewCounter"
  ]

  static values = {
    badgeColors: { type: Array, default: [] },
    recipes: { type: Array, default: [] }
  }

  connect() {
    this.previewIndex = 0
    this.refreshPreviewRecipes()
    this.renderPreview()
  }

  // ── Form toggles ───────────────────────────────────────────────

  kindChanged() {
    this.codeSectionTarget.hidden = this.selectedKind !== "coupon"
    this.updatePreviewBadgeVisibility()
  }

  discountTypeChanged() {
    const dt = this.selectedDiscountType
    this.valuePctWrapTarget.hidden = dt !== "percentage"
    this.valueFixedWrapTarget.hidden = dt !== "fixed_amount"
    this.bogoSectionTarget.hidden = dt !== "bogo"
    this.maxDiscountSectionTarget.hidden = dt !== "percentage"

    if (dt === "percentage") {
      this.valueFixedInputTarget.name = ""
      this.valuePctInputTarget.name = "promotion[discount_value]"
    } else if (dt === "fixed_amount") {
      this.valuePctInputTarget.name = ""
      this.valueFixedInputTarget.name = "promotion[discount_value_pesos]"
    }
    this.updatePreviewDiscount()
  }

  scopeTypeChanged() {
    const st = this.selectedScopeType
    this.recipesSectionTarget.hidden = st !== "recipe"
    this.categoriesSectionTarget.hidden = st !== "category"
    this.previewIndex = 0
    this.refreshPreviewRecipes()
    this.renderPreview()
  }

  validityModeChanged() {
    const vm = this.selectedValidityMode
    this.dateRangeSectionTarget.hidden = vm !== "date_range"
    this.weekdaysSectionTarget.hidden = vm !== "weekdays"
  }

  weekdayToggled(event) {
    this.toggleLabelStyle(event.target)
  }

  tagToggled(event) {
    this.toggleLabelStyle(event.target)
    this.refreshPreviewRecipes()
    this.previewIndex = 0
    this.renderPreview()
  }

  toggleLabelStyle(input) {
    const label = input.closest("label")
    if (!label) return
    const checked = input.checked
    label.classList.toggle("border-accent", checked)
    label.classList.toggle("bg-accent", checked)
    label.classList.toggle("text-bg", checked)
    label.classList.toggle("border-line", !checked)
    label.classList.toggle("bg-surface", !checked)
    label.classList.toggle("text-ink-2", !checked)
  }

  // ── Color picker ──────────────────────────────────────────────

  pickColor(event) {
    event.preventDefault()
    const color = event.currentTarget.dataset.color
    this.badgeColorInputTarget.value = color

    this.element.querySelectorAll("[data-color]").forEach(btn => {
      const sel = btn.dataset.color === color
      btn.classList.toggle("border-ink", sel)
      btn.classList.toggle("scale-110", sel)
      btn.classList.toggle("ring-2", sel)
      btn.classList.toggle("ring-ink/20", sel)
      btn.classList.toggle("border-transparent", !sel)
    })

    this.updatePreviewColors()
  }

  // ── Preview carousel ──────────────────────────────────────────

  refreshPreviewRecipes() {
    const scope = this.selectedScopeType
    const all = this.recipesValue

    if (scope === "order") {
      // Random one
      this.previewRecipes = all.length ? [all[Math.floor(Math.random() * all.length)]] : []
    } else if (scope === "recipe") {
      const selectedIds = this.selectedRecipeIds()
      this.previewRecipes = all.filter(r => selectedIds.has(r.id))
    } else if (scope === "category") {
      const selectedCatIds = this.selectedCategoryIds()
      this.previewRecipes = all.filter(r => selectedCatIds.has(r.category_id))
    } else {
      this.previewRecipes = all.slice(0, 1)
    }

    if (!this.previewRecipes.length && all.length) {
      this.previewRecipes = [all[0]]
    }
  }

  renderPreview() {
    const recipes = this.previewRecipes || []
    const recipe = recipes[this.previewIndex] || recipes[0]

    if (!recipe) return

    // Photo
    if (recipe.photo) {
      this.previewPhotoTarget.src = recipe.photo
      this.previewPhotoTarget.hidden = false
      this.previewPhotoFallbackTarget.hidden = true
    } else {
      this.previewPhotoTarget.hidden = true
      this.previewPhotoFallbackTarget.hidden = false
      this.previewPhotoFallbackTarget.textContent = (recipe.name || "?")[0].toUpperCase()
    }

    // Name + price
    this.previewNameTarget.textContent = recipe.name || ""
    this.previewPriceTarget.textContent = recipe.price || ""

    // Nav
    if (recipes.length > 1) {
      this.previewNavTarget.hidden = false
      this.previewCounterTarget.textContent = `${this.previewIndex + 1} / ${recipes.length}`
    } else {
      this.previewNavTarget.hidden = true
    }

    this.updatePreviewColors()
    this.updatePreviewBadgeVisibility()
    this.updatePreviewDiscount()
  }

  prevPreview(event) {
    event.preventDefault()
    const len = (this.previewRecipes || []).length
    if (len <= 1) return
    this.previewIndex = (this.previewIndex - 1 + len) % len
    this.renderPreview()
  }

  nextPreview(event) {
    event.preventDefault()
    const len = (this.previewRecipes || []).length
    if (len <= 1) return
    this.previewIndex = (this.previewIndex + 1) % len
    this.renderPreview()
  }

  updatePreview() {
    this.updatePreviewColors()
    this.updatePreviewBadgeVisibility()
    this.updatePreviewDiscount()
  }

  updatePreviewColors() {
    const color = this.badgeColorInputTarget.value || "#0A5A3C"
    if (this.hasPreviewLabelTarget) this.previewLabelTarget.style.background = color
  }

  updatePreviewBadgeVisibility() {
    const isAutomatic = this.selectedKind === "automatic"

    // Label overlay on image — only for automatic promos
    if (this.hasPreviewLabelTarget) {
      this.previewLabelTarget.hidden = !isAutomatic
      const labelText = this.hasBadgeLabelInputTarget
        ? this.badgeLabelInputTarget.value.trim() || "PROMO"
        : "PROMO"
      this.previewLabelTarget.textContent = labelText
    }

    // Discount badge next to name — only for automatic promos
    if (this.hasPreviewBadgeTarget) {
      this.previewBadgeTarget.hidden = !isAutomatic
    }
  }

  updatePreviewDiscount() {
    if (!this.hasPreviewBadgeTarget) return
    if (this.selectedKind !== "automatic") return

    const dt = this.selectedDiscountType
    let text = ""
    if (dt === "percentage") {
      const val = this.valuePctInputTarget?.value || ""
      text = val ? `${val}% desc.` : ""
    } else if (dt === "fixed_amount") {
      const val = this.valueFixedInputTarget?.value || ""
      text = val ? `-$${val}` : ""
    } else if (dt === "bogo") {
      const buy = this.element.querySelector("[name='promotion[bogo_buy_quantity]']")?.value || "1"
      const get = this.element.querySelector("[name='promotion[bogo_get_quantity]']")?.value || "1"
      text = `${buy}×${parseInt(buy) + parseInt(get)}`
    }
    this.previewBadgeTarget.textContent = text
    this.previewBadgeTarget.hidden = !text || this.selectedKind !== "automatic"
  }

  // ── Helpers ───────────────────────────────────────────────────

  selectedRecipeIds() {
    const ids = new Set()
    this.recipesSectionTarget.querySelectorAll("input[type=checkbox]:checked").forEach(cb => {
      ids.add(parseInt(cb.value, 10))
    })
    return ids
  }

  selectedCategoryIds() {
    const ids = new Set()
    this.categoriesSectionTarget.querySelectorAll("input[type=checkbox]:checked").forEach(cb => {
      ids.add(parseInt(cb.value, 10))
    })
    return ids
  }

  get selectedKind() {
    return this.kindRadioTargets.find(r => r.checked)?.value || "automatic"
  }

  get selectedDiscountType() {
    return this.discountTypeRadioTargets.find(r => r.checked)?.value || "percentage"
  }

  get selectedScopeType() {
    return this.scopeTypeRadioTargets.find(r => r.checked)?.value || "order"
  }

  get selectedValidityMode() {
    return this.validityModeRadioTargets.find(r => r.checked)?.value || "always"
  }
}
