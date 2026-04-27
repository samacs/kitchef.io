# Singular resource — one schedule per account in v1. The settings
# (order_mode + lead_time_minutes) autosave directly against this
# controller. Availabilities are a nested collection that each row edits
# on its own via Schedules::AvailabilitiesController.
class SchedulesController < AuthenticatedController
  def show
    @schedule = Current.account.schedule!
  end

  # Autosave for the Schedule's own settings. Returns 204 No Content for
  # XHR (autosave) requests so the page doesn't refetch; falls back to a
  # full-page redirect for non-JS clients that happen to hit this endpoint.
  def update
    @schedule = Current.account.schedule!

    if @schedule.update(schedule_params)
      respond_to do |format|
        format.html { redirect_to schedule_path, notice: t(".updated") }
        format.any  { head :no_content }
      end
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_content }
        format.any  { render json: { errors: @schedule.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  private

  def schedule_params
    permitted = params.require(:schedule).permit(
      :order_mode, :lead_time_hours,
      :vacation_until, :vacation_message
    )

    # "" (operator clicked "Reanudar mi cocina" → empty field) reads
    # back as a real Date.parse error in dev. Normalize empty string
    # to nil so clearing the pause is a one-click operation. Same for
    # the message — empty string clears the override copy.
    permitted[:vacation_until]   = nil if permitted.key?(:vacation_until)   && permitted[:vacation_until].blank?
    permitted[:vacation_message] = nil if permitted.key?(:vacation_message) && permitted[:vacation_message].blank?
    permitted
  end
end
