module Onboarding
  # Spins up an operator's kitchen once she submits the first onboarding
  # step. Runs inside a transaction so the account + free subscription +
  # user.account_id link either all succeed or none do — a half-created
  # kitchen leaves the sign-in flow in an ambiguous state that's a pain
  # to diagnose.
  class CreateAccount < ApplicationCommand
    option :user
    option :name
    option :slug, optional: true

    def call
      ActiveRecord::Base.transaction do
        account = user.build_owned_account(account_attributes)

        unless account.save
          return failure(account.errors)
        end

        Subscription.create!(account: account, plan: :free, status: :active)
        user.update!(account: account)

        success(account)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors)
    end

    private

    # Always write an explicit slug so FriendlyID's default `:slugged`
    # strategy doesn't reach for its UUID-suffixed fallback on collisions
    # (52 chars → exceeds the 50-char max and throws a confusing
    # validation). With an explicit slug, a duplicate fails the Account
    # uniqueness validator with a clear "slug has already been taken"
    # message the controller can surface.
    def account_attributes
      provided = slug.to_s.strip
      {
        name: name.to_s.strip,
        slug: provided.presence || Account.slugify(name)
      }
    end
  end
end
