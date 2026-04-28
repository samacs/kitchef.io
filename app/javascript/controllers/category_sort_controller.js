import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list"]
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.listTarget, {
      animation: 150,
      delay: 200,
      delayOnTouchOnly: true,
      handle: "[data-sort-handle]",
      ghostClass: "kc-category-ghost",
      dragClass: "kc-category-drag",
      onEnd: () => this.#persist()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  #persist() {
    const ids = [...this.listTarget.querySelectorAll("[data-category-id]")]
      .map(el => el.dataset.categoryId)

    this.listTarget.querySelectorAll("[data-position-label]").forEach((el, idx) => {
      el.textContent = String(idx + 1)
    })

    if (ids.length === 0) return

    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        Accept: "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ ids })
    })
  }
}
