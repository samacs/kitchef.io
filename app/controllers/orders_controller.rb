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
        redirect_to orders_path, notice: t(".#{event}")
      else
        redirect_to orders_path, alert: t("orders.transitions.errors.not_allowed")
      end
    end
  end

  private

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
