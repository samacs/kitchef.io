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
    params.require(:schedule).permit(:order_mode, :lead_time_minutes)
  end
end
