import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "kindRadio",
    "codeSection",
    "discountTypeRadio",
    "valueSection",
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
    "weekdaysSection"
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

    this.valuePctWrapTarget.hidden = dt !== "percentage"
    this.valueFixedWrapTarget.hidden = dt !== "fixed_amount"

    if (dt === "percentage") {
      this.valueFixedInputTarget.name = ""
      this.valuePctInputTarget.name = "promotion[discount_value]"
    } else if (dt === "fixed_amount") {
      this.valuePctInputTarget.name = ""
      this.valueFixedInputTarget.name = "promotion[discount_value_pesos]"
    }
  }

  scopeTypeChanged() {
    const st = this.selectedScopeType
    this.recipesSectionTarget.hidden = st !== "recipe"
    this.categoriesSectionTarget.hidden = st !== "category"
  }

  validityModeChanged() {
    const vm = this.selectedValidityMode
    this.dateRangeSectionTarget.hidden = vm !== "date_range"
    this.weekdaysSectionTarget.hidden = vm !== "weekdays"
  }

  weekdayToggled(event) {
    const label = event.target.closest("label")
    if (!label) return
    const checked = event.target.checked
    label.classList.toggle("border-accent", checked)
    label.classList.toggle("bg-accent", checked)
    label.classList.toggle("text-bg", checked)
    label.classList.toggle("border-line", !checked)
    label.classList.toggle("bg-surface", !checked)
    label.classList.toggle("text-ink-2", !checked)
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

  get selectedValidityMode() {
    const checked = this.validityModeRadioTargets.find(r => r.checked)
    return checked ? checked.value : "always"
  }
}
