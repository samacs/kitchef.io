class OrdersController < AuthenticatedController
  expose :orders, -> { Current.account.orders.kept.includes(:client, items: :recipe).order(created_at: :desc) }
  expose :order,  -> { find_or_build_order }

  # Canceled and paid pedidos are terminal — edits go through "Duplicar"
  # (creates a fresh draft) so the audit trail stays clean and reports
  # don't see post-hoc mutations. Applies to edit/update/destroy only;
  # the drawer still opens for inspection through a read-only drawer
  # later if we want one.
  before_action :reject_if_immutable, only: %i[edit update destroy]

  def index; end
  def new;   end
  def edit;  end

  def create
    result = Orders::Place.call(account: Current.account, params: order_params)
    if result.success?
      redirect_to orders_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity, locals: { order: result.object }
    end
  end

  def update
    result = Orders::Update.call(order: order, params: order_params)
    if result.success?
      respond_to do |format|
        # Quick-edit flow: the drawer stays open so operators can keep
        # tweaking. We replace the kanban card in place (precise morph
        # via its dom_id) rather than refreshing the whole page — the
        # operator never loses focus. Other tabs still get the normal
        # broadcast refresh.
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(order),
            partial: "orders/card",
            locals: { order: order }
          )
        end
        format.html { redirect_to orders_path, notice: t(".updated") }
      end
    else
      render :edit, status: :unprocessable_entity, locals: { order: result.object }
    end
  end

  def destroy
    order.discard
    redirect_to orders_path, notice: t(".discarded")
  end

  Orders::Transition::EVENTS.each do |event|
    define_method(event) do
      result = Orders::Transition.call(order: order, event: event)
      if result.success?
        mark_related_notifications_read(order) if event == :confirm

        respond_to do |format|
          # Turbo-stream response keeps the operator where she clicked
          # — e.g. pressing "Confirmar" in the notifications inbox
          # updates the inbox row in place instead of yanking her to
          # the kanban. Any page that doesn't render notifications
          # just ignores the empty stream; the kanban's own
          # broadcasts_refreshes_to handler still redraws the card
          # from `[account, :orders]` when state flips.
          format.turbo_stream do
            if event == :confirm && request.referer&.include?("/notifications")
              render "orders/transition_from_notifications",
                locals: { order: order, notice: t(".#{event}") }
            else
              redirect_to orders_path, notice: t(".#{event}")
            end
          end
          format.html { redirect_to orders_path, notice: t(".#{event}") }
        end
      else
        respond_to do |format|
          format.turbo_stream { redirect_to orders_path, alert: t("orders.transitions.errors.not_allowed") }
          format.html         { redirect_to orders_path, alert: t("orders.transitions.errors.not_allowed") }
        end
      end
    end
  end

  private

  # When the operator confirms a storefront order (from the kanban card OR
  # from the notifications inbox), sweep any unread Noticed events pointing
  # at this order to `read_at`. Without this, the bell badge would keep
  # showing the notification even though the operator has already acted.
  def mark_related_notifications_read(order)
    return unless Current.user

    Current.user.notifications
      .joins(:event)
      .where("noticed_events.params @> ?", { order_id: order.id }.to_json)
      .where(read_at: nil)
      .find_each(&:mark_as_read!)
  rescue StandardError => e
    Rails.logger.warn "[OrdersController] could not sweep notifications for order #{order.id}: #{e.message}"
  end

  def reject_if_immutable
    return if order.new_record? || !order.immutable?

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.update("drawer_content", "") }
      format.html { redirect_to orders_path, alert: t("orders.errors.immutable") }
    end
  end

  def find_or_build_order
    return new_order if params[:id].blank?

    Current.account.orders.kept.find(params[:id])
  end

  def new_order
    Current.account.orders.new(
      delivery_date: Date.current,
      delivery_type: :delivery,
      source:        :manual
    )
  end

  def order_params
    params.require(:order).permit(
      :client_id, :delivery_type, :source, :delivery_date,
      :delivery_start_time_hhmm, :delivery_end_time_hhmm,
      :colonia, :city, :delivery_address, :delivery_notes, :notes,
      items_attributes: %i[id recipe_id quantity unit_price notes _destroy]
    )
  end
end
