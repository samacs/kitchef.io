import { Controller } from "@hotwired/stimulus"

// Debounced live search for list pages. Attach to the `<form>` that
// wraps the search field; each keystroke schedules a submit that fires
// after `wait` ms of keyboard quiet. Pairs naturally with Turbo Frames:
// set `data-turbo-frame="…"` on the form and the result list swaps in
// place without a full navigation.
//
// Usage:
//   <%= form_with url: clients_path, method: :get,
//         html: { data: { controller: "search-debounce",
//                         action: "input->search-debounce#search",
//                         turbo_frame: "clients_results" } } do |f| %>
//     <%= f.search_field :q, value: params[:q], ... %>
//   <% end %>
//
//   <%= turbo_frame_tag "clients_results" do %>
//     <!-- the table / empty state -->
//   <% end %>
export default class extends Controller {
  static values = { wait: { type: Number, default: 250 } }

  disconnect() {
    clearTimeout(this.timeout)
  }

  search(event) {
    clearTimeout(this.timeout)
    // Submit on Enter immediately — don't make the user wait for the
    // debounce window when they've clearly signalled they're done.
    if (event.type === "submit" || event.key === "Enter") {
      this.#submit()
      return
    }
    this.timeout = setTimeout(() => this.#submit(), this.waitValue)
  }

  #submit() {
    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
