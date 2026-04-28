module Searchable
  extend ActiveSupport::Concern

  included do
    class_attribute :_searchable_columns, default: []
  end

  class_methods do
    # Declare which columns to search via pg_trgm similarity.
    #
    #   searchable_on :name, :slug
    #   searchable_on :first_name, :last_name, :phone_normalized, :email
    #
    def searchable_on(*columns)
      self._searchable_columns = columns.map(&:to_s).freeze
    end

    # Returns records ranked by trigram similarity. Must be called on an
    # already-scoped relation (e.g. account.clients.omnisearch("elen")).
    #
    # The threshold defaults to 0.15 — low enough for short Spanish names
    # with a typo or two ("elen" → "Elena", "tamal vrde" → "tamal verde").
    #
    def omnisearch(term, limit: 5, threshold: 0.15)
      return none if term.blank?
      return none if _searchable_columns.empty?

      sanitized = connection.quote(term.downcase.strip)

      similarity_exprs = _searchable_columns.map do |col|
        "similarity(COALESCE(LOWER(#{connection.quote_column_name(col)}), ''), #{sanitized})"
      end

      best_score = "GREATEST(#{similarity_exprs.join(', ')})"

      where("#{best_score} >= ?", threshold)
        .order(Arel.sql("#{best_score} DESC"))
        .limit(limit)
        .select("#{table_name}.*, #{best_score} AS search_score")
    end
  end
end
