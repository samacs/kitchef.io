module AccountScoped
  extend ActiveSupport::Concern

  # Opt-in concern for tenant-scoped records. Enforces the `account_id`
  # association and adds the `.for_account` scope used everywhere in
  # Panel:: controllers and background jobs.
  #
  # We deliberately do NOT set a default_scope on Current.account — that path
  # leads to subtle bugs when a job runs without a current tenant, or when
  # admin tooling needs cross-tenant reads. All scoping is explicit via
  # `.for_account(account)` or via the association (`account.clients.…`).
  included do
    belongs_to :account

    scope :for_account, ->(account) { where(account: account) }
  end
end
