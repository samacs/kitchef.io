# Weekly delivery-slot grid — one slot per weekday, with optional
# capacity cap and a live fill indicator driven by this week's pedidos.
#
# v1 is display-only for capacity. Storefront checkout continues to read
# slots unfiltered; actually blocking submissions past the cap waits for
# demand data (Phase 6+). The indicator is here to nudge operators to
# raise their number when they feel constrained.
class DeliverySlotsController < AuthenticatedController
  def index
    @slots_by_day = Current.account.delivery_slots.order(:day_of_week, :start_time).group_by(&:day_of_week)
    @week_starting = Date.current.beginning_of_week(:monday).to_date
    @fill_levels = fill_levels_for(@week_starting)
  end

  def create
    slot = Current.account.delivery_slots.new(slot_params)
    slot.day_of_week = params[:day_of_week].to_i

    if slot.save
      redirect_to delivery_slots_path, notice: t(".created")
    else
      redirect_to delivery_slots_path, alert: slot.errors.full_messages.to_sentence
    end
  end

  def update
    slot = Current.account.delivery_slots.find(params[:id])
    if slot.update(slot_params)
      redirect_to delivery_slots_path, notice: t(".updated")
    else
      redirect_to delivery_slots_path, alert: slot.errors.full_messages.to_sentence
    end
  end

  def destroy
    slot = Current.account.delivery_slots.find(params[:id])
    slot.destroy
    redirect_to delivery_slots_path, notice: t(".destroyed")
  end

  private

  def slot_params
    params.require(:delivery_slot).permit(:start_time_hhmm, :end_time_hhmm, :capacity, :max_orders)
  end

  def fill_levels_for(week_starting)
    Current.account.delivery_slots.each_with_object({}) do |slot, acc|
      acc[slot.id] = DeliverySlots::FillLevel.for(account: Current.account, slot: slot, week_starting: week_starting)
    end
  end
end
