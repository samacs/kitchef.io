# == Schema Information
#
# Table name: recipe_components
#
#  id                 :bigint           not null, primary key
#  componentable_type :string           not null
#  is_removable       :boolean          default(FALSE), not null
#  notes              :text
#  position           :integer
#  quantity           :decimal(10, 3)   not null
#  unit               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  componentable_id   :bigint           not null
#  recipe_id          :bigint           not null
#
# Indexes
#
#  index_recipe_components_on_componentable           (componentable_type,componentable_id)
#  index_recipe_components_on_recipe_id               (recipe_id)
#  index_recipe_components_on_recipe_id_and_position  (recipe_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (recipe_id => recipes.id)
#
class RecipeComponent < ApplicationRecord
  positioned on: :recipe

  belongs_to :recipe
  belongs_to :componentable, polymorphic: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :unit, presence: true
  validate  :componentable_is_ingredient_or_recipe
  validate  :no_direct_self_reference
  validate  :no_deep_cycle
  validate  :cross_account_components_rejected
  validate  :unit_compatible_with_componentable
  validate  :removable_only_for_ingredients

  after_commit :enqueue_parent_cost_refresh, on: %i[create update destroy]

  # Returns the componentable's canonical cost unit (an Ingredient's unit
  # or a Recipe's yield_unit). Used by Recipes::CostCalculator to convert
  # quantities during cost resolution.
  def componentable_canonical_unit
    case componentable
    when Ingredient then componentable.unit
    when Recipe     then componentable.yield_unit
    end
  end

  private

  def componentable_is_ingredient_or_recipe
    return if componentable_type.in?(%w[Ingredient Recipe])

    errors.add(:componentable_type, :invalid)
  end

  def no_direct_self_reference
    return unless componentable_type == "Recipe"
    return unless componentable_id == recipe_id

    errors.add(:componentable, :self_reference)
  end

  # Belt-and-suspenders cycle check. The UI layer prevents the operator
  # from picking a cyclic recipe via `Recipes::CycleDetector`; this
  # validator rejects anything that slips past (direct API POSTs,
  # console edits, etc.).
  def no_deep_cycle
    return unless componentable_type == "Recipe"
    return if componentable_id.blank? || recipe_id.blank?
    return if componentable_id == recipe_id # covered by :self_reference
    return unless Recipes::CycleDetector.would_cycle?(parent: recipe, candidate: componentable)

    errors.add(:componentable, :cycle)
  end

  def unit_compatible_with_componentable
    canonical = componentable_canonical_unit
    return if canonical.blank? || unit.blank?
    return if Recipes::UnitConverter.compatible?(unit, canonical)

    errors.add(:unit, :incompatible)
  end

  # After any component edit fires, refresh the parent recipe's cost
  # cache AND every recipe that uses the parent (one level of fan-out
  # is free; the job walks the rest via DependencyGraph).
  def enqueue_parent_cost_refresh
    return if recipe_id.blank?

    RecipeCostRefreshJob.perform_later(recipe_id: recipe_id)
  end

  # Components must live in the same account as the parent recipe. Block at
  # validation time rather than trusting the UI — it's cheap, and it keeps
  # cross-tenant leakage impossible via API misuse.
  def removable_only_for_ingredients
    return unless is_removable?
    return if componentable_type == "Ingredient"

    errors.add(:is_removable, :only_ingredients)
  end

  def cross_account_components_rejected
    return unless recipe && componentable.respond_to?(:account_id)
    return if componentable.account_id == recipe.account_id

    errors.add(:componentable, :cross_account)
  end
end
