import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.querySelectorAll("[data-width]").forEach(el => {
      el.style.width = el.dataset.width
    })
    this.element.querySelectorAll("[data-height]").forEach(el => {
      el.style.height = el.dataset.height
    })
  }
}
