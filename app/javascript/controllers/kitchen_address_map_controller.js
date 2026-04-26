import { Controller } from "@hotwired/stimulus"

// Bidirectional address ↔ map for the kitchen pickup address.
//
// Uses Google's recommended inline bootstrapper so `importLibrary` is
// always available — even if a legacy Maps API script was loaded by a
// previous Turbo Drive navigation or a browser extension.
//
// The map is ALWAYS rendered when an API key is present. If the account
// has saved lat/lon, the marker starts there. Otherwise it defaults to
// CDMX so the operator always sees a draggable pin she can move.
export default class extends Controller {
  static targets = ["input", "map", "suggestions", "lat", "lon", "fallback", "directionsLink"]
  static values = {
    apiKey:      String,
    initialLat:  { type: Number, default: 0 },
    initialLon:  { type: Number, default: 0 },
    fallbackLat: { type: Number, default: 19.4326 },
    fallbackLon: { type: Number, default: -99.1332 }
  }

  async connect() {
    this._lastSuggestions = []

    if (!this.apiKeyValue) {
      this.#showFallback()
      this.#syncDirectionsLink()
      return
    }

    try {
      this.#bootstrapGoogleMaps()
      await this.#initMap()
      this.#syncDirectionsLink()
    } catch (err) {
      console.warn("kitchen-address-map: Google Maps failed to load", err)
      this.#showFallback()
    }
  }

  // ── Public actions ───────────────────────────────────────────────────

  async search() {
    const query = this.inputTarget.value.trim()
    if (query.length < 3) { this.#hideSuggestions(); return }
    if (!this.AutocompleteSuggestion) return

    try {
      const { suggestions } = await this.AutocompleteSuggestion.fetchAutocompleteSuggestions({
        input: query, sessionToken: this.sessionToken,
        includedRegionCodes: [ "mx" ], language: "es"
      })
      const trimmed = (suggestions || []).slice(0, 3)
      if (trimmed.length === 0) { this.#hideSuggestions(); return }
      this.#renderAutocompleteSuggestions(trimmed)
    } catch (err) {
      console.warn("kitchen-address-map: autocomplete failed", err)
      this.#hideSuggestions()
    }
  }

  async pickAutocomplete(event) {
    const idx = parseInt(event.currentTarget.dataset.idx, 10)
    const suggestion = this._lastSuggestions[idx]
    if (!suggestion?.placePrediction) return
    try {
      const place = suggestion.placePrediction.toPlace()
      await place.fetchFields({ fields: [ "location" ] })
      const loc = place.location
      if (!loc) return
      const lat = typeof loc.lat === "function" ? loc.lat() : loc.lat
      const lng = typeof loc.lng === "function" ? loc.lng() : loc.lng
      this.#setCoords(lat, lng)
      this.#moveMap(lat, lng)
      this.#hideSuggestions()
      this.sessionToken = new this.AutocompleteSessionToken()
    } catch (err) { console.warn("kitchen-address-map: place fetch failed", err) }
  }

  pickReverse(event) {
    const lat = parseFloat(event.currentTarget.dataset.lat)
    const lng = parseFloat(event.currentTarget.dataset.lng)
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      this.#setCoords(lat, lng)
      this.#moveMap(lat, lng)
    }
    this.#hideSuggestions()
  }

  hideSuggestionsSoon() {
    clearTimeout(this._hideTimer)
    this._hideTimer = setTimeout(() => this.#hideSuggestions(), 200)
  }

  cancelHide() { clearTimeout(this._hideTimer) }

  // ── Google Maps bootstrap ────────────────────────────────────────────
  //
  // Google's recommended inline bootstrapper defines `importLibrary` on
  // `google.maps` BEFORE the actual JS bundle loads. This sidesteps the
  // Turbo Drive cache problem where a stale `google.maps` global
  // (without `importLibrary`) blocks the async loader.

  #bootstrapGoogleMaps() {
    if (typeof google !== "undefined" && google.maps?.importLibrary && typeof google.maps.importLibrary === "function") {
      return
    }

    const g = window.google || (window.google = {})
    const m = g.maps || (g.maps = {})

    if (typeof m.importLibrary === "function") return

    const pending = new Set()
    let loaderPromise = null

    m.importLibrary = (lib) => {
      pending.add(lib)
      if (!loaderPromise) {
        loaderPromise = new Promise((resolve, reject) => {
          const script = document.createElement("script")
          const params = new URLSearchParams({
            key: this.apiKeyValue, v: "weekly",
            libraries: [...pending].join(","),
            language: "es", region: "MX", callback: "google.maps.__ib__"
          })
          script.src = `https://maps.googleapis.com/maps/api/js?${params}`
          script.async = true
          m.__ib__ = resolve
          script.onerror = () => reject(new Error("Google Maps script failed"))
          document.head.appendChild(script)
        })
      }
      return loaderPromise.then(() => m.importLibrary(lib))
    }
  }

  async #initMap() {
    const { Map }    = await google.maps.importLibrary("maps")
    const { Marker } = await google.maps.importLibrary("marker")
    const { Geocoder } = await google.maps.importLibrary("geocoding")

    let AutocompleteSuggestion, AutocompleteSessionToken
    try {
      const places = await google.maps.importLibrary("places")
      AutocompleteSuggestion  = places.AutocompleteSuggestion
      AutocompleteSessionToken = places.AutocompleteSessionToken
    } catch (e) {
      console.warn("kitchen-address-map: Places API not available, autocomplete disabled")
    }

    const startLat   = this.#parseFloat(this.latTarget.value) || this.initialLatValue || this.fallbackLatValue
    const startLon   = this.#parseFloat(this.lonTarget.value) || this.initialLonValue || this.fallbackLonValue
    const haveCoords = !!(this.#parseFloat(this.latTarget.value) || this.initialLatValue)

    this.map = new Map(this.mapTarget, {
      center: { lat: startLat, lng: startLon },
      zoom: haveCoords ? 16 : 12,
      streetViewControl: false, mapTypeControl: false,
      fullscreenControl: false, clickableIcons: false,
      gestureHandling: "cooperative"
    })

    this.marker = new Marker({
      map: this.map, position: { lat: startLat, lng: startLon },
      draggable: true, title: "Arrastra para ajustar"
    })

    this.marker.addListener("dragend", () => {
      const pos = this.marker.getPosition()
      if (!pos) return
      this.#setCoords(pos.lat(), pos.lng())
      this.#reverseGeocode({ lat: pos.lat(), lng: pos.lng() })
    })

    this.geocoder = new Geocoder()
    this.AutocompleteSuggestion   = AutocompleteSuggestion || null
    this.AutocompleteSessionToken = AutocompleteSessionToken || null
    if (AutocompleteSessionToken) this.sessionToken = new AutocompleteSessionToken()
  }

  // ── Internals ────────────────────────────────────────────────────────

  #moveMap(lat, lng) {
    this.map.panTo({ lat, lng })
    if (this.map.getZoom() < 14) this.map.setZoom(16)
    this.marker.setPosition({ lat, lng })
    this.marker.setVisible(true)
  }

  #setCoords(lat, lng) {
    const latStr = Number.isFinite(lat) ? lat.toFixed(6) : ""
    const lonStr = Number.isFinite(lng) ? lng.toFixed(6) : ""
    if (this.latTarget.value === latStr && this.lonTarget.value === lonStr) return
    this.latTarget.value = latStr
    this.lonTarget.value = lonStr
    this.latTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.#syncDirectionsLink()
  }

  async #reverseGeocode(latLng) {
    if (!this.geocoder) return
    try {
      const { results } = await this.geocoder.geocode({ location: latLng })
      if (!results?.length) { this.#hideSuggestions(); return }
      this.#renderReverseSuggestions(results.slice(0, 3))
    } catch (err) {
      console.warn("kitchen-address-map: reverse geocode failed", err)
      this.#hideSuggestions()
    }
  }

  #renderAutocompleteSuggestions(suggestions) {
    this._lastSuggestions = suggestions
    this.suggestionsTarget.innerHTML = suggestions.map((s, idx) => {
      const pred = s.placePrediction
      const main = pred?.structuredFormat?.mainText?.text || pred?.text?.toString?.() || ""
      const sub  = pred?.structuredFormat?.secondaryText?.text || ""
      return `
        <button type="button" data-action="mousedown->kitchen-address-map#cancelHide click->kitchen-address-map#pickAutocomplete" data-idx="${idx}"
                class="block w-full text-left px-3 py-2 hover:bg-bg-2 border-b border-line last:border-b-0 cursor-pointer transition-colors">
          <span class="block text-[13px] text-ink">${this.#esc(main)}</span>
          ${sub ? `<span class="block text-[11.5px] text-muted">${this.#esc(sub)}</span>` : ""}
        </button>`
    }).join("")
    this.suggestionsTarget.classList.remove("hidden")
  }

  #renderReverseSuggestions(results) {
    this.suggestionsTarget.innerHTML = results.map(r => {
      const loc = r.geometry?.location
      const lat = typeof loc?.lat === "function" ? loc.lat() : 0
      const lng = typeof loc?.lng === "function" ? loc.lng() : 0
      return `
        <button type="button" data-action="mousedown->kitchen-address-map#cancelHide click->kitchen-address-map#pickReverse" data-lat="${lat}" data-lng="${lng}"
                class="block w-full text-left px-3 py-2 hover:bg-bg-2 border-b border-line last:border-b-0 cursor-pointer transition-colors">
          <span class="block text-[13px] text-ink">${this.#esc(r.formatted_address || "")}</span>
        </button>`
    }).join("")
    this.suggestionsTarget.classList.remove("hidden")
  }

  #hideSuggestions() {
    this.suggestionsTarget.classList.add("hidden")
    this.suggestionsTarget.innerHTML = ""
    this._lastSuggestions = []
  }

  #syncDirectionsLink() {
    if (!this.hasDirectionsLinkTarget) return
    const lat = this.#parseFloat(this.latTarget.value)
    const lon = this.#parseFloat(this.lonTarget.value)
    if (Number.isFinite(lat) && Number.isFinite(lon) && (lat !== 0 || lon !== 0)) {
      this.directionsLinkTarget.href = `https://www.google.com/maps/dir/?api=1&destination=${lat},${lon}&travelmode=driving`
      this.directionsLinkTarget.classList.remove("hidden")
    } else {
      this.directionsLinkTarget.classList.add("hidden")
    }
  }

  #showFallback() {
    if (this.hasFallbackTarget) this.fallbackTarget.classList.remove("hidden")
    if (this.hasMapTarget) this.mapTarget.classList.add("hidden")
  }

  #parseFloat(v) { const n = parseFloat(v); return Number.isFinite(n) ? n : 0 }

  #esc(str) {
    return String(str || "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c])
  }
}
