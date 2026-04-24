module Recipes
  # Given a parent Recipe and a candidate componentable (Ingredient or
  # Recipe), returns true when adding that candidate as a component of
  # the parent would introduce a cycle.
  #
  # Ingredients are always safe (they're leaves — they never reference
  # other components). Recipes need a BFS walk: from the candidate,
  # follow its recipe-typed components; if we ever land on the parent,
  # we'd cycle.
  #
  # The polymorphic RecipeComponent model already guards against direct
  # self-reference at validation time. This service catches the deeper
  # case (A → B → A, A → B → C → A, etc.) at the UI layer so the form
  # can disable the option BEFORE submit.
  class CycleDetector
    def self.would_cycle?(parent:, candidate:)
      return false unless candidate.is_a?(Recipe)
      return true  if parent.id.nil? || candidate.id == parent.id

      visited = Set.new
      queue = [ candidate.id ]

      until queue.empty?
        current_id = queue.shift
        next if visited.include?(current_id)

        visited << current_id
        return true if current_id == parent.id

        RecipeComponent
          .where(recipe_id: current_id, componentable_type: "Recipe")
          .pluck(:componentable_id)
          .each { |child_id| queue << child_id unless visited.include?(child_id) }
      end

      false
    end
  end
end
