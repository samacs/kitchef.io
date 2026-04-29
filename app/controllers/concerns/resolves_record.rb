module ResolvesRecord
  extend ActiveSupport::Concern

  private

  # Resolves a record from params[:id] (or a custom param) trying three
  # strategies in order:
  #
  #   1. Prefixed id  — "rec_qjW8hYvz" → HasPrefixedId.find_by_prefix_id
  #   2. FriendlyId   — "pozole-rojo"  → friendly.find (slug lookup)
  #   3. Numeric id   — "42"           → find_by(id:)
  #
  # Returns nil when no strategy matches (caller decides whether to raise
  # or build a new record).
  def resolve_record(scope, id = params[:id])
    return nil if id.blank?

    id_str = id.to_s

    if id_str.include?("_") && scope.klass.respond_to?(:find_by_prefix_id)
      found = scope.find_by_prefix_id(id_str)
      return found if found
    end

    if scope.klass.respond_to?(:friendly)
      found = scope.friendly.find(id_str)
      return found
    end

    scope.find_by(id: id_str)
  rescue ActiveRecord::RecordNotFound
    scope.find_by(id: id_str)
  end
end
