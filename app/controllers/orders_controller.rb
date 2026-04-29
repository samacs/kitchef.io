class OrdersController < AuthenticatedController
  expose :orders, -> { Current.account.orders.kept.includes(:client, items: :recipe).order(created_at: :desc) }
  expose :order,  -> { find_or_build_order }

  # Canceled and delivered pedidos are terminal — edits go through
  # "Duplicar" (creates a fresh draft) so the audit trail stays clean
  # and reports don't see post-hoc mutations. The drawer for `edit`
  # still opens but renders a read-only summary (see
  # `_immutable_drawer.html.erb`); `update` / `destroy` reject with
  # an alert because they're action POSTs, not inspection requests.
  before_action :reject_if_immutable, only: %i[update destroy]

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

        # Deep-link to the moved card via URL fragment so
        # target_highlight_controller auto-scrolls + flashes it in the
        # new column. The fragment is only useful on the kanban page
        # — the notifications-inbox flow below short-circuits to its
        # own turbo_stream template.
        redirect_target = orders_path(anchor: helpers.dom_id(order))

        respond_to do |format|
          format.turbo_stream do
            if event == :confirm && request.referer&.include?("/notifications")
              render "orders/transition_from_notifications",
                locals: { order: order, notice: t(".#{event}") }
            else
              redirect_to redirect_target, notice: t(".#{event}")
            end
          end
          format.html { redirect_to redirect_target, notice: t(".#{event}") }
        end
      else
        respond_to do |format|
          format.turbo_stream { redirect_to orders_path, alert: t("orders.transitions.errors.not_allowed") }
          format.html         { redirect_to orders_path, alert: t("orders.transitions.errors.not_allowed") }
        end
      end
    end
  end

  # Payment capture. Stamps `paid_at` without touching AASM — a canceled
  # order is rejected; everything else is idempotent, so a double-tap
  # doesn't error. The kanban card is broadcast back (via the Order's
  # `broadcasts_refreshes_to` on any update) so the paid chip morphs on
  # every open dashboard.
  def mark_paid
    if order.mark_paid!
      redirect_to orders_path(anchor: helpers.dom_id(order)), notice: t(".marked_paid")
    else
      redirect_to orders_path, alert: t(".mark_paid_blocked")
    end
  end

  # Undo button for mis-clicks — clears `paid_at` and restores the
  # outstanding balance. No state change.
  def unmark_paid
    order.unmark_paid!
    redirect_to orders_path(anchor: helpers.dom_id(order)), notice: t(".unmarked_paid")
  end

  # Whole-column bulk transition from the kanban header menu. Fires the
  # matching event on every eligible order in the column in one DB
  # transaction. Sequential-in-process so the per-card Turbo broadcasts
  # stay ordered — ≤20 pedidos per column keeps this well under a second.
  def bulk_transition
    event = params[:event].to_s
    unless Orders::BulkTransition::EVENT_SOURCE_STATE.key?(event.to_sym)
      return redirect_to orders_path, alert: t("orders.bulk.errors.unsupported")
    end

    result = Orders::BulkTransition.call(account: Current.account, event: event)
    outcome = result.object
    notice = bulk_flash_message(event: event, outcome: outcome)
    redirect_to orders_path, notice: notice
  end

  private

  def bulk_flash_message(event:, outcome:)
    return t("orders.bulk.#{event}.empty") if outcome.succeeded_count.zero? && outcome.failed_count.zero?

    parts = []
    parts << t("orders.bulk.#{event}.succeeded", count: outcome.succeeded_count) if outcome.succeeded_count.positive?
    parts << t("orders.bulk.#{event}.failed", count: outcome.failed_count) if outcome.failed_count.positive?
    parts.join(" · ")
  end


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

    resolve_record(Current.account.orders.kept) ||
      raise(ActiveRecord::RecordNotFound)
  end

  def new_order
    Current.account.orders.new(
      delivery_date:   Date.current,
      delivery_type:   :delivery,
      source:          :manual,
      packaging_cents: Current.account.settings.default_packaging_cents.to_i
    )
  end

  def order_params
    params.require(:order).permit(
      :client_id, :delivery_type, :source, :delivery_date,
      :delivery_start_time_hhmm, :delivery_end_time_hhmm,
      :colonia, :city, :delivery_address, :delivery_notes, :notes,
      :packaging, :packaging_cents, :coupon_code,
      items_attributes: %i[id recipe_id quantity unit_price notes _destroy]
    ).then { |p| normalize_packaging(p) }
  end

  # Convert a free-form peso input ("10", "10.50") to cents once on the
  # way in. Keeps the form honest whether the operator types cents
  # directly or a familiar pesos number.
  def normalize_packaging(permitted)
    raw = permitted.delete(:packaging)
    return permitted if raw.blank?
    normalized = raw.to_s.gsub(",", ".").to_d
    permitted[:packaging_cents] = (normalized * 100).to_i
    permitted
  end
end
