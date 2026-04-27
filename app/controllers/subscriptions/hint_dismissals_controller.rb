module Subscriptions
  # Receives the POST from a `Subscriptions::HintBanner` "x" button
  # and writes a `DismissedHint` row keyed by the current account
  # and the banner's `hint_key`. Idempotent: re-posting the same key
  # bumps `dismissed_at` and updates `redismiss_at` if provided.
  #
  # The component renders Turbo's default form, so a successful POST
  # naturally redirects the operator back to wherever she was. The
  # banner's `render?` method skips itself on the next paint because
  # the dismissal row exists.
  class HintDismissalsController < AuthenticatedController
    def create
      key = params[:hint_key].to_s.strip
      return head(:bad_request) if key.blank?

      hint = Current.account.dismissed_hints
                    .find_or_initialize_by(hint_key: key)
      hint.dismissed_at = Time.current
      hint.redismiss_at = parse_redismiss_at(params[:redismiss_at])
      hint.save!

      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, status: :see_other }
        format.turbo_stream { head :no_content }
      end
    end

    private

    # Accept ISO8601 strings only. Blank means permanent dismissal.
    def parse_redismiss_at(raw)
      return nil if raw.blank?
      Time.iso8601(raw)
    rescue ArgumentError
      nil
    end
  end
end
