# Daily focus view + weekly shopping list — the operator's 7am "what am I
# doing today" surface. Parallel to the kanban: the kanban is card-first,
# this is schedule-first. See docs/PRD.md (Phase 5) for the routine these
# answer.
class ProductionController < AuthenticatedController
  def show
    @on = parse_date(params[:on]) || Date.current
    @week_starting = @on
    @week_overview = Production::WeekOverview.for(account: Current.account, starting: @week_starting)
    @plan = Production::DailyPlan.for(account: Current.account, on: @on)
  end

  def shopping_list
    @starting = Date.current
    @list = Production::WeeklyShoppingList.for(account: Current.account, starting: @starting)

    # Phase 9 — overlay the purchase ledger so rows already marked as
    # comprada render with a persistent ✓ + the actual price she paid.
    # Scope: purchases whose purchased_on falls inside the shopping-list
    # window. Keyed by ingredient_id so the per-row lookup is O(1).
    end_date = @list.ending
    purchased_items = PurchaseItem
      .joins(:purchase)
      .where(purchases: { account_id: Current.account.id, discarded_at: nil, purchased_on: @starting..end_date })
      .includes(purchase: :supplier)
      .group_by(&:ingredient_id)
    @marked_by_ingredient = purchased_items.transform_values do |items|
      MarkSummary.new(
        last_item:   items.max_by { |i| i.purchase.purchased_on },
        total_cents: items.sum(&:subtotal_cents)
      )
    end
    @weekly_spent_cents = @marked_by_ingredient.values.sum(&:total_cents)
    @weekly_marked_count = @marked_by_ingredient.size
  end

  MarkSummary = Data.define(:last_item, :total_cents)

  # "Iniciar producción de todas" bulk action, firing on every `confirmed`
  # order whose `delivery_date` matches. Scoped to a single day so the
  # operator can bulk-start tomorrow without also sweeping orders for the
  # day after. Dedicated action (not /orders/bulk) because the filter is
  # date-based, not column-based.
  def bulk_start_production
    on = parse_date(params[:on]) || Date.current
    orders = Current.account.orders.kept
      .where(delivery_date: on, state: "confirmed")
      .order(:position, :id)

    succeeded = 0
    failed = 0
    ActiveRecord::Base.transaction do
      orders.each do |order|
        if order.aasm.may_fire_event?(:start_production) && order.start_production!
          succeeded += 1
        else
          failed += 1
        end
      end
    end

    notice = bulk_flash_message(succeeded: succeeded, failed: failed, event: :start_production)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: [
          turbo_stream.refresh(request_id: SecureRandom.uuid),
          turbo_stream.append("flash-region", partial: "shared/flash_region")
        ]
      end
      format.html { redirect_to production_path(on: on.to_s), notice: notice }
    end
  end

  private

  def parse_date(raw)
    return nil if raw.blank?

    Date.iso8601(raw.to_s)
  rescue Date::Error
    nil
  end

  def bulk_flash_message(succeeded:, failed:, event:)
    return I18n.t("production.bulk.#{event}.empty") if succeeded.zero? && failed.zero?

    parts = []
    parts << I18n.t("production.bulk.#{event}.succeeded", count: succeeded) if succeeded.positive?
    parts << I18n.t("production.bulk.#{event}.failed", count: failed) if failed.positive?
    parts.join(" · ")
  end
end
