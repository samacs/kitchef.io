import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "kindRadio",
    "codeSection",
    "discountTypeRadio",
    "valueSection",
    "valuePrefix",
    "bogoSection",
    "maxDiscountSection",
    "scopeTypeRadio",
    "recipesSection",
    "categoriesSection"
  ]

  kindChanged() {
    const kind = this.selectedKind
    this.codeSectionTarget.hidden = kind !== "coupon"
  }

  discountTypeChanged() {
    const dt = this.selectedDiscountType
    this.valueSectionTarget.hidden = dt === "bogo"
    this.bogoSectionTarget.hidden = dt !== "bogo"
    this.maxDiscountSectionTarget.hidden = dt !== "percentage"

    if (this.hasValuePrefixTarget) {
      this.valuePrefixTarget.textContent = dt === "percentage" ? "%" : "$"
    }
  }

  scopeTypeChanged() {
    const st = this.selectedScopeType
    this.recipesSectionTarget.hidden = st !== "recipe"
    this.categoriesSectionTarget.hidden = st !== "category"
  }

  get selectedKind() {
    const checked = this.kindRadioTargets.find(r => r.checked)
    return checked ? checked.value : "automatic"
  }

  get selectedDiscountType() {
    const checked = this.discountTypeRadioTargets.find(r => r.checked)
    return checked ? checked.value : "percentage"
  }

  get selectedScopeType() {
    const checked = this.scopeTypeRadioTargets.find(r => r.checked)
    return checked ? checked.value : "order"
  }
}
