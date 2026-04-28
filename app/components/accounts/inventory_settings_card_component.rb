module Accounts
  # /account/edit card that exposes the Phase 13 inventory toggle plus
  # the per-account knobs that only matter when inventory is on
  # (oversell policy, low-stock threshold, default run window).
  #
  # Renders inside the autosave form, so any change to the toggle posts
  # the whole account form. The controller redirects to the onboarding
  # primer when the toggle flips from off → on.
  class InventorySettingsCardComponent < ApplicationComponent
    option :account
    option :form

    def settings
      account.inventory_settings
    end

    def enabled?
      settings.enabled
    end

    def block_oversells?
      settings.block_oversells?
    end

    # Free accounts see a locked variant: the toggle is shown so the
    # feature is discoverable, but it's disabled and the section CTA
    # points at the upgrade flow instead. Stays in sync with the
    # `inventory` entitlement check the model enforces at runtime.
    def pro_locked?
      !Entitlements.for(account).allows?(:inventory)
    end
  end
end
