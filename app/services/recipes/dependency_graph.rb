module Recipes
  # Given an Ingredient or a Recipe, return every Recipe whose cost tree
  # includes it — at any depth. Used by the ingredient-price-change
  # impact panel (Slice 5) and by RecipeCostRefreshJob to fan out on
  # save.
  #
  # Implementation: PostgreSQL recursive CTE starting from the direct
  # parents of the componentable, walking upward through recipe→recipe
  # edges. Result deduplicates (a recipe can reach a leaf through
  # multiple paths).
  class DependencyGraph
    def self.recipes_depending_on(componentable:)
      new(componentable).recipes
    end

    def initialize(componentable)
      @componentable = componentable
    end

    def recipes
      return Recipe.none if ids.empty?

      Recipe.where(id: ids)
    end

    # Returns the set of recipe IDs that depend on the componentable,
    # directly or transitively. Exposed separately from `recipes` so
    # callers who just need count/existence skip the Recipe load.
    def ids
      @ids ||= compute_ids
    end

    private

    attr_reader :componentable

    def compute_ids
      type = componentable.class.base_class.name
      id   = componentable.id
      return [] if id.nil?

      sql = <<~SQL.squish
        WITH RECURSIVE ancestors AS (
          SELECT recipe_id
          FROM recipe_components
          WHERE componentable_type = $1 AND componentable_id = $2

          UNION

          SELECT rc.recipe_id
          FROM recipe_components rc
          JOIN ancestors a
            ON rc.componentable_type = 'Recipe'
           AND rc.componentable_id   = a.recipe_id
        )
        SELECT DISTINCT recipe_id FROM ancestors
      SQL

      binds = [ type, id ]
      Recipe.connection.exec_query(sql, "DependencyGraph", binds).rows.flatten
    end
  end
end
