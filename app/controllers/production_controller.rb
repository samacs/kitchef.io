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
  end

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
    redirect_to production_path(on: on.to_s), notice: notice
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
