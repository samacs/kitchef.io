module Orders
  # Cancellation drawer — `GET /orders/:order_id/cancellation/new` renders
  # a focused form (reason picker + optional note), `POST` fires the
  # cancel event with the captured reason. On success the drawer closes
  # and the kanban morphs the card into the cancelados strip via the
  # Order's broadcasts_refreshes_to.
  class CancellationsController < AuthenticatedController
    expose :order, -> { Current.account.orders.kept.find(params[:order_id]) }

    def new
      # Guard: if the pedido is already past-cancelable (paid / canceled),
      # redirect back instead of showing an unusable form.
      redirect_drawer_away unless order.aasm.may_fire_event?(:cancel)
    end

    def create
      result = ::Orders::Cancel.call(order: order, params: cancel_params)

      if result.success?
        respond_to do |format|
          format.turbo_stream { render turbo_stream: close_drawer_and_refresh }
          format.html { redirect_to orders_path, notice: t(".canceled") }
        end
      else
        render :new, status: :unprocessable_entity, locals: { order: result.object }
      end
    end

    private

    def cancel_params
      params.fetch(:order, {}).permit(:cancel_reason_code, :cancel_reason_note)
    end

    # The drawer listens for an empty frame and closes on its own; any
    # HTML landing page also works for the rare direct-URL hit.
    def redirect_drawer_away
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update("drawer_content", "") }
        format.html { redirect_to orders_path, alert: t("orders.transitions.errors.not_allowed") }
      end
    end
  end
end
