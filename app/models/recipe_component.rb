# == Schema Information
#
# Table name: recipe_components
#
#  id                 :bigint           not null, primary key
#  componentable_type :string           not null
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
  validate  :cross_account_components_rejected

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

  # Components must live in the same account as the parent recipe. Block at
  # validation time rather than trusting the UI — it's cheap, and it keeps
  # cross-tenant leakage impossible via API misuse.
  def cross_account_components_rejected
    return unless recipe && componentable.respond_to?(:account_id)
    return if componentable.account_id == recipe.account_id

    errors.add(:componentable, :cross_account)
  end
end
