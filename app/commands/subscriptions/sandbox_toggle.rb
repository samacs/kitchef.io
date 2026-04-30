module Subscriptions
  # Toggle an account between Free and Pro locally when Stripe is not
  # configured. Sets `source: :sandbox` so these rows are easy to
  # identify and nuke before going live with production Stripe keys.
  class SandboxToggle < ApplicationCommand
    option :account
    option :plan # "free" or "pro"

    def call
      return failure([ "stripe_is_enabled" ]) if Subscriptions.stripe_enabled?

      sub = account.subscription || account.create_subscription!

      if plan.to_s == "pro"
        upgrade_to_pro!(sub)
      else
        downgrade_to_free!(sub)
      end

      success(sub)
    end

    private

    def upgrade_to_pro!(sub)
      sub.update!(
        source: :sandbox,
        plan:   :pro_monthly,
        status: :active
      )
    end

    def downgrade_to_free!(sub)
      sub.update!(
        source: :free,
        plan:   :free,
        status: :active
      )
    end
  end
end
