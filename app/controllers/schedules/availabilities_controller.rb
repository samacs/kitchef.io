module Schedules
  # Per-availability CRUD on the single Schedule. Every response is a
  # Turbo Stream so the /schedule page mutates in place — no full-form
  # round-trip, no nested-attributes double-create fragility.
  #
  # Shape of the DOM the streams target:
  #   <div id="availabilities_wday_<N>">   … recurring slots for a weekday
  #   <div id="availabilities_exceptions"> … date-specific exceptions
  #   <div id="availability_<id>">         … a single row (form)
  class AvailabilitiesController < AuthenticatedController
    def create
      schedule = Current.account.schedule!
      availability = schedule.availabilities.new(availability_params)

      # Sensible defaults for a freshly-added row so the autosaving row
      # doesn't fail validation on the first PATCH. Operator picks real
      # times + the row re-autosaves.
      availability.from_time ||= 9 * 60
      availability.to_time   ||= 18 * 60

      if availability.save
        respond_to do |format|
          format.turbo_stream { render turbo_stream: append_stream(availability) }
          format.html { redirect_to schedule_path }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: flash_error(availability.errors.full_messages.first) }
          format.html { redirect_to schedule_path, alert: availability.errors.full_messages.to_sentence }
        end
      end
    end

    def update
      availability = Current.account.schedule!.availabilities.find(params[:id])

      if availability.update(availability_params)
        # Quiet success — the DOM already shows the new values, the form's
        # autosave status pill is the only confirmation we need.
        respond_to do |format|
          format.turbo_stream { head :no_content }
          format.html         { redirect_to schedule_path, notice: t(".updated") }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: flash_error(availability.errors.full_messages.first) }
          format.html         { redirect_to schedule_path, alert: availability.errors.full_messages.to_sentence }
        end
      end
    end

    def destroy
      availability = Current.account.schedule!.availabilities.find(params[:id])
      availability.destroy

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(availability)) }
        format.html         { redirect_to schedule_path, notice: t(".destroyed") }
      end
    end

    private

    def availability_params
      params.require(:availability).permit(
        :wday, :date, :from_time_hhmm, :to_time_hhmm, :available, :note
      )
    end

    # Append to the right container: recurring → the weekday block, override
    # → the exceptions list. The view's partials render the same row shape
    # for both.
    def append_stream(availability)
      target =
        if availability.wday.present?
          "availabilities_wday_#{availability.wday}"
        else
          "availabilities_exceptions"
        end

      turbo_stream.append target, partial: "schedules/availability_row",
        locals: { availability: availability }
    end

    def flash_error(message)
      turbo_stream.update "schedule_flash",
        render_to_string(
          partial: "shared/flash_inline",
          locals: { kind: :alert, message: message }
        )
    rescue StandardError
      turbo_stream.update "schedule_flash", "<p class=\"text-err text-[13px]\">#{ERB::Util.html_escape(message)}</p>".html_safe
    end
  end
end
