import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "groups", "group", "destroyFlag",
    "groupTemplate", "optionTemplate",
    "optionsList", "optionRow", "optionDestroyFlag",
    "optionsContainer", "empty",
    "componentableRow", "componentableQty", "componentableUnit"
  ]

  static values = { nextIndex: { type: Number, default: 0 } }

  addGroup(event) {
    event.preventDefault()
    const idx = this.nextIndexValue++
    const html = this.groupTemplateTarget.innerHTML.replaceAll("NEW_INDEX", idx)
    const wrapper = document.createElement("div")
    wrapper.innerHTML = html.trim()
    const node = wrapper.firstElementChild

    if (this.hasEmptyTarget) this.emptyTarget.remove()
    this.groupsTarget.appendChild(node)
  }

  removeGroup(event) {
    event.preventDefault()
    const group = event.target.closest("[data-recipe-option-groups-target='group']")
    if (!group) return

    const idInput = group.querySelector("input[name$='[id]']")
    const destroyFlag = group.querySelector("[data-recipe-option-groups-target='destroyFlag']")

    if (idInput?.value && destroyFlag) {
      destroyFlag.value = "1"
      group.classList.add("hidden")
    } else {
      group.remove()
    }
  }

  addOption(event) {
    event.preventDefault()
    const group = event.target.closest("[data-recipe-option-groups-target='group']")
    if (!group) return

    const list = group.querySelector("[data-recipe-option-groups-target='optionsList']")
    if (!list) return

    const groupIndex = this._groupIndex(group)
    const optionIndex = list.querySelectorAll("[data-recipe-option-groups-target='optionRow']").length

    const prefix = `recipe[option_groups_attributes][${groupIndex}][options_attributes][${optionIndex}]`
    const html = this.optionTemplateTarget.innerHTML.replaceAll("OPTION_PREFIX", prefix)
    const wrapper = document.createElement("div")
    wrapper.innerHTML = html.trim()
    list.appendChild(wrapper.firstElementChild)
  }

  removeOption(event) {
    event.preventDefault()
    const row = event.target.closest("[data-recipe-option-groups-target='optionRow']")
    if (!row) return

    const idInput = row.querySelector("input[name$='[id]']")
    const destroyFlag = row.querySelector("[data-recipe-option-groups-target='optionDestroyFlag']")

    if (idInput?.value && destroyFlag) {
      destroyFlag.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }
  }

  kindChanged(event) {
    const group = event.target.closest("[data-recipe-option-groups-target='group']")
    if (!group) return

    const kind = event.target.value
    const optionsContainer = group.querySelector("[data-recipe-option-groups-target='optionsContainer']")
    if (optionsContainer) {
      optionsContainer.classList.toggle("hidden", kind === "textarea")
    }
  }

  componentableChanged(event) {
    const row = event.target.closest("[data-recipe-option-groups-target='optionRow']")
    if (!row) return

    const val = event.target.value
    const typeInput = row.querySelector("input[name$='[componentable_type]']")
    const idInput = row.querySelector("input[name$='[componentable_id]']")
    const qtyInput = row.querySelector("[data-recipe-option-groups-target='componentableQty']")
    const unitSelect = row.querySelector("[data-recipe-option-groups-target='componentableUnit']")

    if (val) {
      const [type, id] = val.split(":")
      if (typeInput) typeInput.value = type
      if (idInput) idInput.value = id

      const selected = event.target.selectedOptions[0]
      const defaultUnit = selected?.dataset?.unit || ""

      if (qtyInput) qtyInput.classList.remove("hidden")
      if (unitSelect) {
        unitSelect.classList.remove("hidden")
        if (defaultUnit) unitSelect.value = defaultUnit
      }
    } else {
      if (typeInput) typeInput.value = ""
      if (idInput) idInput.value = ""
      if (qtyInput) { qtyInput.classList.add("hidden"); qtyInput.value = "" }
      if (unitSelect) unitSelect.classList.add("hidden")
    }
  }

  _groupIndex(groupEl) {
    const nameInput = groupEl.querySelector("input[name*='option_groups_attributes']")
    if (!nameInput) return 0
    const match = nameInput.name.match(/option_groups_attributes\[(\d+)\]/)
    return match ? match[1] : 0
  }
}
