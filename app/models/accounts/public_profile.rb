module Accounts
  # Per-account public-facing profile copy, persisted as a JSONB column on
  # accounts.public_profile and typed via the `store_model` gem.
  #
  # Every attribute is optional so the operator can finish onboarding with
  # just a kitchen name + slug and come back to polish the rest later.
  class PublicProfile
    include StoreModel::Model

    DESCRIPTION_MAX = 280

    attribute :description, :string, default: ""
    attribute :tagline,     :string, default: ""

    validates :description, length: { maximum: DESCRIPTION_MAX }
    validates :tagline,     length: { maximum: 80 }
  end
end
