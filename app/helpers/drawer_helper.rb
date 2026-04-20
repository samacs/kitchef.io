module DrawerHelper
  # Builds a link that opens its target inside the shared right-side
  # drawer (rendered once by the panel layout). Pairs with the
  # `right-drawer` Stimulus controller and a `turbo-frame id="drawer_content"`
  # wrapper in the destination view.
  #
  #   <%= drawer_link_to t("orders.form.submit_update"), edit_order_path(order),
  #         class: "text-[12px] font-medium text-accent hover:underline" %>
  #
  #   <%= drawer_link_to edit_client_path(client), aria: { label: t("clients.row.edit") } do %>
  #     <%= icon(:pencil, size: :sm) %>
  #   <% end %>
  #
  # Call sites never have to remember the two data attributes — the
  # helper stamps them so every drawer entry point stays consistent.
  def drawer_link_to(name = nil, options = nil, html_options = nil, &block)
    if block_given?
      html_options = options || {}
      options = name
      name = capture(&block)
    end
    html_options = (html_options || {}).deep_dup

    data = (html_options[:data] || {}).dup
    data[:turbo_frame] = "drawer_content"
    existing_action = data[:action]
    data[:action] = [ existing_action, "click->right-drawer#open" ].compact.join(" ")
    html_options[:data] = data

    link_to(name, options, html_options)
  end
end
