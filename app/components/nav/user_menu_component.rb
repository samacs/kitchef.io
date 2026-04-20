module Nav
  # Signed-in user dropdown — used in the marketing header when the
  # visitor is authenticated, and in the dashboard sidebar's bottom
  # identity card. Pixel-perfect responsive: trigger collapses to just
  # the avatar under sm, expands to avatar + name + plan kicker at md+.
  #
  #   <%= render Nav::UserMenuComponent.new(
  #         current_user: Current.user,
  #         current_account: Current.account,
  #         variant: :chip,       # :chip (default) | :card (sidebar)
  #         placement: :bottom_end
  #       ) %>
  class UserMenuComponent < ApplicationComponent
    VARIANTS = %i[chip card].freeze

    option :current_user
    option :current_account, optional: true
    option :variant,   default: -> { :chip }
    option :placement, default: -> { :bottom_end }

    def display_name = current_user.name.to_s
    def email        = current_user.email_address.to_s
    def kitchen_name = current_account&.name

    # Reads the live plan off the account's subscription. Falls back to
    # `free` so unauthenticated chrome (or a half-created account that
    # hasn't hit Subscription.create! yet) still renders a sensible
    # "Plan Gratis" label instead of crashing on nil.
    def plan_label
      key = current_account&.subscription&.plan || "free"
      t("user_menu.plan_#{key}")
    end
  end
end
