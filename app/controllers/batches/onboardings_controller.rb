module Batches
  # One-screen primer that fires the first time the operator flips the
  # inventory toggle on. Skipped for accounts that already have it on
  # (we don't want a returning operator to land here every time she
  # touches /account/edit).
  class OnboardingsController < AuthenticatedController
    def show
      unless Current.account.inventory_enabled?
        redirect_to edit_account_path and return
      end
    end
  end
end
