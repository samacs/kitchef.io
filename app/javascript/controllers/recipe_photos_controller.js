import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Recipe-form photo tiles. Three responsibilities:
//
//   1. UPLOAD via tap-to-pick or drag-drop onto the canvas. Adds a
//      preview tile + a hidden file input the form submit picks up.
//   2. REMOVE existing photos by appending the attachment id to a
//      hidden `recipe[remove_photo_ids][]` array; the tile fades out
//      so the operator sees the change immediately.
//   3. REORDER via Sortable.js (touch + mouse). On drop, rewrite the
//      hidden `recipe[photo_order]` array so the controller can
//      apply the position column on save.
//
// Targets:
//   - canvas       — the tile grid root (Sortable wraps this)
//   - tile         — each photo or empty slot (Sortable items)
//   - fileInput    — the native <input type="file"> we forward to
//   - orderInput   — hidden text input that holds the JSON ordered list
//   - removeIdsInput — hidden input array; cumulative as the operator
//                      removes tiles
//   - emptyHint    — the "Toma cerca de una ventana" tip; only renders
//                    when no photos attached. Hidden as soon as the
//                    operator adds her first
//
// Values:
//   - max (Number) — Pro: 6, Free: 1. Beyond it, the empty slot
//     renders the "Pro" lock placeholder; this controller still
//     runs on Free pages (1 slot) for upload + replace.
export default class extends Controller {
  static targets = [
    "canvas",
    "tile",
    "fileInput",
    "orderInput",
    "removeIdsInput",
    "emptyHint"
  ]

  static values = {
    max: { type: Number, default: 6 }
  }

  connect() {
    this.removedIds = new Set()
    this.pendingFiles = []
    this.#initSortable()
    this.#refreshOrder()
  }

  disconnect() {
    this.sortable?.destroy()
  }

  // ── Public actions ────────────────────────────────────────────────

  // Tile click → forward to the hidden file input.
  pickFile(event) {
    if (event.target.closest("[data-recipe-photos-target='tile'][data-state='filled']")) return
    if (event.target.closest("[data-recipe-photos-action]")) return
    this.fileInputTarget?.click()
  }

  // Drop file on the canvas → forward to the file input.
  filesDropped(event) {
    event.preventDefault()
    const files = event.dataTransfer?.files
    if (!files || files.length === 0) return
    this.#addFiles(files)
  }

  preventDefault(event) {
    event.preventDefault()
  }

  // Native file input changed → render preview tiles + keep the
  // input intact so the form submit carries the files.
  filesPicked(event) {
    const files = event.target.files
    if (!files || files.length === 0) return
    this.#addFiles(files)
  }

  // X button on a tile → mark for removal.
  removeTile(event) {
    event.preventDefault()
    const tile = event.currentTarget.closest("[data-recipe-photos-target='tile']")
    if (!tile) return

    const attachmentId = tile.dataset.attachmentId
    if (attachmentId) {
      this.removedIds.add(attachmentId)
      this.#paintRemovedIds()
      tile.remove()
    } else if (tile.dataset.state === "pending") {
      const pendingIdx = Number(tile.dataset.pendingIndex)
      this.pendingFiles.splice(pendingIdx, 1)
      this.#syncFileInput()
      this.#renderPendingPreviews()
    }

    this.#refreshOrder()
    this.#refreshEmptyHint()
    this.#dispatchPhotoCount()
  }

  // ── Internals ─────────────────────────────────────────────────────

  #initSortable() {
    if (!this.hasCanvasTarget) return
    this.sortable = Sortable.create(this.canvasTarget, {
      animation: 150,
      delay: 200,                         // long-press on touch before drag starts
      delayOnTouchOnly: true,
      handle: "[data-recipe-photos-handle]",
      filter: "[data-state='locked'],[data-state='empty']",
      preventOnFilter: false,             // empty/locked tiles still tap to pick
      ghostClass: "kc-photo-tile-ghost",
      onEnd: () => this.#refreshOrder()
    })
  }

  // Add new files to our own accumulator. We can't rely on
  // `fileInputTarget.files` as a source of truth because each fresh
  // user pick REPLACES the input's files (the browser doesn't
  // accumulate across picks), and on the change event the input is
  // already the new selection — so iterating it would double-count.
  #addFiles(fileList) {
    Array.from(fileList).forEach(f => this.pendingFiles.push(f))
    this.#syncFileInput()
    this.#renderPendingPreviews()
    this.#refreshEmptyHint()
    this.#dispatchPhotoCount()
  }

  #syncFileInput() {
    const dt = new DataTransfer()
    this.pendingFiles.forEach(f => dt.items.add(f))
    this.fileInputTarget.files = dt.files
  }

  #renderPendingPreviews() {
    this.canvasTarget
        .querySelectorAll("[data-state='pending']")
        .forEach(t => t.remove())

    const empty = this.canvasTarget.querySelector("[data-state='empty']")

    this.pendingFiles.forEach((file, idx) => {
      const tile = this.#buildPendingTile(file, idx)
      if (empty) {
        this.canvasTarget.insertBefore(tile, empty)
      } else {
        this.canvasTarget.appendChild(tile)
      }
    })
    this.#refreshOrder()
  }

  #buildPendingTile(file, idx) {
    const url = URL.createObjectURL(file)
    const tile = document.createElement("li")
    tile.className = "kc-photo-tile"
    tile.dataset.recipePhotosTarget = "tile"
    tile.dataset.state = "pending"
    tile.dataset.pendingIndex = String(idx)

    tile.innerHTML = `
      <span class="kc-photo-tile-handle" data-recipe-photos-handle>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <circle cx="9"  cy="6"  r="1"/><circle cx="15" cy="6"  r="1"/>
          <circle cx="9"  cy="12" r="1"/><circle cx="15" cy="12" r="1"/>
          <circle cx="9"  cy="18" r="1"/><circle cx="15" cy="18" r="1"/>
        </svg>
      </span>
      <button type="button"
              class="kc-photo-tile-remove"
              data-action="click->recipe-photos#removeTile"
              aria-label="Quitar foto">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" aria-hidden="true">
          <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
        </svg>
      </button>
      <img src="${url}" alt="" loading="lazy" class="kc-photo-tile-img"/>
    `
    return tile
  }

  #refreshOrder() {
    if (!this.hasOrderInputTarget) return
    const order = this.tileTargets
      .filter(t => t.dataset.state === "filled" || t.dataset.state === "pending")
      .map(t => {
        if (t.dataset.state === "pending") {
          return { kind: "pending", index: Number(t.dataset.pendingIndex) }
        }
        return { kind: "existing", id: Number(t.dataset.attachmentId) }
      })
    this.orderInputTarget.value = JSON.stringify(order)
  }

  #paintRemovedIds() {
    if (!this.hasRemoveIdsInputTarget) return
    this.removeIdsInputTarget.value = Array.from(this.removedIds).join(",")
  }

  #refreshEmptyHint() {
    if (!this.hasEmptyHintTarget) return
    const filledCount = this.#filledCount
    this.emptyHintTarget.classList.toggle("hidden", filledCount > 0)
  }

  #dispatchPhotoCount() {
    this.dispatch("changed", { detail: { count: this.#filledCount } })
  }

  get #filledCount() {
    return this.tileTargets.filter(t =>
      t.dataset.state === "filled" || t.dataset.state === "pending"
    ).length
  }
}
