module Searchable
  extend ActiveSupport::Concern

  included do
    class_attribute :_searchable_columns, default: []
  end

  class_methods do
    def searchable_on(*columns)
      self._searchable_columns = columns.map(&:to_s).freeze
    end

    def omnisearch(term, limit: 5, threshold: 0.15)
      return none if term.blank?
      return none if _searchable_columns.empty?

      clean = term.downcase.strip
      score_expr = _build_score_expression(clean)

      where("#{score_expr} >= ?", threshold)
        .order(Arel.sql("#{score_expr} DESC"))
        .limit(limit)
        .select("#{table_name}.*, #{score_expr} AS search_score")
    end

    private

    def _build_score_expression(term)
      quoted_term = connection.quote(term)

      similarity_calls = _searchable_columns.map do |col|
        quoted_col = connection.quote_column_name(col)
        "similarity(unaccent(COALESCE(LOWER(#{quoted_col}), '')), unaccent(#{quoted_term}))"
      end

      Arel.sql("GREATEST(#{similarity_calls.join(', ')})")
    end
  end
end
