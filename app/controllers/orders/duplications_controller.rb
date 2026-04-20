module Orders
  # Creates a fresh `placed` pedido from an existing (usually canceled)
  # one. Entered via the Duplicar icon on a canceled card. Success path
  # redirects to the new pedido's edit view — when called from within
  # the drawer, Turbo loads the new edit form into the drawer in place,
  # ready for the operator to confirm / tweak / re-capture.
  class DuplicationsController < AuthenticatedController
    expose :order, -> { Current.account.orders.kept.find(params[:order_id]) }

    def create
      result = ::Orders::Duplicate.call(source: order, account: Current.account)

      if result.success?
        redirect_to edit_order_path(result.object), notice: t(".duplicated")
      else
        redirect_to orders_path, alert: t(".failed")
      end
    end
  end
end
