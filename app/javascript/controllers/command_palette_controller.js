import { Controller } from "@hotwired/stimulus"

// Global command palette (⌘K / Ctrl+K). Rendered once in the panel
// layout; the top-bar search input acts as a trigger. Fetches results
// via a Turbo Frame pointed at /search.
//
// Targets:
//   - dialog:   the <dialog> element
//   - input:    the search field inside the palette
//   - results:  the container where result rows live
//   - trigger:  the top-bar pseudo-input that opens the palette
//
// Values:
//   - url:  the search endpoint (default /search)
//   - wait: debounce ms (default 200)
export default class extends Controller {
  static targets = ["dialog", "input", "results"]
  static values = {
    url: { type: String, default: "/search" },
    wait: { type: Number, default: 200 }
  }

  connect() {
    this.activeIndex = -1
    this.isMac = navigator.userAgentData?.platform === "macOS"
      || /Mac|iPhone|iPad|iPod/.test(navigator.userAgent)
    this.onGlobalKey = this.#handleGlobalKey.bind(this)
    this.onGlobalOpen = () => this.open()
    document.addEventListener("keydown", this.onGlobalKey)
    window.addEventListener("command-palette:open", this.onGlobalOpen)
    this.#setKbdHints()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onGlobalKey)
    window.removeEventListener("command-palette:open", this.onGlobalOpen)
    clearTimeout(this.debounceTimer)
  }

  // ── Public actions ────────────────────────────────────────────────

  open(event) {
    event?.preventDefault()
    if (this.dialogTarget.open) return
    this.dialogTarget.showModal()
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.activeIndex = -1
  }

  close() {
    if (!this.dialogTarget.open) return
    this.dialogTarget.close()
    this.activeIndex = -1
  }

  // Fired on backdrop click (the <dialog> itself, not inner content).
  backdropClick(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  // Input handler — debounced fetch. Ignores navigation keys so
  // arrow-key selection doesn't trigger a re-fetch that resets it.
  type(event) {
    const ignore = ["Escape", "ArrowDown", "ArrowUp", "Enter", "Tab"]
    if (ignore.includes(event.key)) return
    clearTimeout(this.debounceTimer)
    this.activeIndex = -1
    const q = this.inputTarget.value.trim()

    if (q.length === 0) {
      this.#clearResults()
      return
    }

    this.debounceTimer = setTimeout(() => this.#fetch(q), this.waitValue)
  }

  // Immediate submit on Enter inside the input (when no row is active).
  submit(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    const active = this.#activeRow()
    if (active) {
      this.#navigate(active)
    } else {
      clearTimeout(this.debounceTimer)
      const q = this.inputTarget.value.trim()
      if (q.length > 0) this.#fetch(q)
    }
  }

  // Keyboard navigation inside the palette.
  navigate(event) {
    const rows = this.#rows()
    if (rows.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, rows.length - 1)
      this.#paintActive(rows)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, -1)
      this.#paintActive(rows)
      if (this.activeIndex === -1) this.inputTarget.focus()
    } else if (event.key === "Enter") {
      event.preventDefault()
      const active = this.#activeRow()
      if (active) this.#navigate(active)
    }
  }

  // Called when the Turbo Frame finishes loading results.
  resultsLoaded() {
    this.activeIndex = -1
    this.#paintActive(this.#rows())
  }

  // Close the palette when a result link is clicked directly.
  rowClicked() {
    this.close()
  }

  // ── Internals ─────────────────────────────────────────────────────

  #setKbdHints() {
    if (!this.isMac) return
    document.querySelectorAll("[data-kbd-shortcut]").forEach(el => {
      el.textContent = el.textContent.replace("Ctrl+", "⌘")
    })
  }

  #handleGlobalKey(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "k") {
      event.preventDefault()
      if (this.dialogTarget.open) {
        this.close()
      } else {
        this.open()
      }
    }
  }

  #fetch(q) {
    const frame = this.resultsTarget.querySelector("turbo-frame")
    if (!frame) return
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", q)
    url.searchParams.set("palette", "1")
    frame.src = url.toString()
  }

  #clearResults() {
    const frame = this.resultsTarget.querySelector("turbo-frame")
    if (frame) frame.innerHTML = ""
    this.activeIndex = -1
  }

  #rows() {
    return [...this.resultsTarget.querySelectorAll("[data-palette-row]")]
  }

  #activeRow() {
    const rows = this.#rows()
    return rows[this.activeIndex] || null
  }

  #paintActive(rows) {
    rows.forEach((row, i) => {
      row.classList.toggle("kc-palette-active", i === this.activeIndex)
    })
    const active = rows[this.activeIndex]
    if (active) active.scrollIntoView({ block: "nearest" })
  }

  #navigate(row) {
    const href = row.getAttribute("href") || row.querySelector("a")?.getAttribute("href")
    if (!href) return
    this.close()
    Turbo.visit(href)
  }
}
