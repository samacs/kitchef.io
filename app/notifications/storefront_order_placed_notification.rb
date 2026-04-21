# Dispatched from Storefronts::PlaceOrder when a customer submits their
# cart. Recipient is the account owner (a `User`). Two delivery lanes:
#
#   * Database (automatic in Noticed 3) — row in `noticed_notifications`
#     powers the inbox at `/notifications` and the bell badge count.
#   * ActionCable — broadcasts a Turbo Stream refresh on the recipient's
#     `:notifications` channel so the top-bar bell and inbox morph live.
#
# A per-operator email channel is intentionally left off this phase — the
# customer already gets a confirmation email (StorefrontOrdersMailer), and
# the in-app bell + inbox is enough for the operator side. When we add an
# opt-out email lane, the `notify_new_orders` flag on Accounts::Settings
# is already waiting.
class StorefrontOrderPlacedNotification < Noticed::Event
  deliver_by :action_cable do |config|
    config.channel = "Turbo::StreamsChannel"
    config.stream  = ->(recipient) { [ recipient, :notifications ] }
    config.message = ->(_notification) { { kind: "refresh" } }
  end

  required_param :order_id

  def order
    @order ||= Order.find_by(id: params[:order_id])
  end

  # The operator doesn't have a per-order show page — pedidos live on the
  # kanban at `/orders`. Deep-link there with the card's dom_id as a URL
  # fragment so `scroll-mt-*` + `:target` ring make the card obvious.
  def url
    return Rails.application.routes.url_helpers.orders_path if order.nil?

    "#{Rails.application.routes.url_helpers.orders_path}##{ActionView::RecordIdentifier.dom_id(order)}"
  end

  def title
    I18n.t("notifications.storefront_order_placed.title",
           client: client_name,
           total:  formatted_total)
  end

  def body
    I18n.t("notifications.storefront_order_placed.body",
           date: I18n.l(order.delivery_date, format: :long))
  end

  private

  def client_name
    order.client&.name.presence || I18n.t("notifications.storefront_order_placed.anonymous_client")
  end

  def formatted_total
    Money.new(order.total_cents, "MXN").format(symbol: "$", thousands_separator: ",", decimal_mark: ".")
  end
end
