module HasSoftDelete
  extend ActiveSupport::Concern

  # Wraps the `discard` gem with our conventions:
  # - Record keeps `discarded_at` (timestamp) — required migration column.
  # - Default scope still returns every row; use `.kept` for the common path.
  # - `.discarded` returns only deleted records for reports and audit screens.
  #
  # Why discard over paranoia / acts_as_paranoid: discard leaves the default
  # ActiveRecord behavior untouched (no surprising `default_scope` side
  # effects), and leaves decision-making explicit at the call site.
  included do
    include Discard::Model

    scope :kept,      -> { undiscarded }
    scope :discarded, -> { with_discarded.where.not(discarded_at: nil) }
  end
end
