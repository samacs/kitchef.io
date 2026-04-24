# == Schema Information
#
# Table name: supplier_ingredients
#
#  id                     :bigint           not null, primary key
#  currency               :string           default("MXN"), not null
#  is_default_cost_source :boolean          default(FALSE), not null
#  last_bought_on         :date
#  notes                  :text
#  unit_cost_cents        :bigint           default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  ingredient_id          :bigint           not null
#  supplier_id            :bigint           not null
#
# Indexes
#
#  index_supplier_ingredients_on_ingredient_id  (ingredient_id)
#  index_supplier_ingredients_on_supplier_id    (supplier_id)
#  uniq_default_supplier_per_ingredient         (ingredient_id) UNIQUE WHERE (is_default_cost_source = true)
#  uniq_supplier_ingredient                     (supplier_id,ingredient_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ingredient_id => ingredients.id) ON DELETE => cascade
#  fk_rails_...  (supplier_id => suppliers.id) ON DELETE => cascade
#
class SupplierIngredient < ApplicationRecord
  belongs_to :supplier
  belongs_to :ingredient

  monetize :unit_cost_cents

  validates :unit_cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :supplier_id, uniqueness: { scope: :ingredient_id }
  validate  :supplier_and_ingredient_share_account

  # When this row is (or was) the default, re-cache the ingredient's
  # derived `unit_cost_cents`. Phase 7's `Recipes::DependencyGraph`
  # cascade handles the downstream recipe recompute.
  after_save    :refresh_ingredient_cost_cache_if_default
  after_destroy :refresh_ingredient_cost_cache_if_default

  scope :default, -> { where(is_default_cost_source: true) }

  # Promote this row to default, demoting any other row for the same
  # ingredient. Returns self.
  def promote_to_default!
    transaction do
      self.class.where(ingredient_id: ingredient_id)
        .where.not(id: id)
        .update_all(is_default_cost_source: false)
      update!(is_default_cost_source: true)
    end
    self
  end

  private

  def supplier_and_ingredient_share_account
    return if supplier.blank? || ingredient.blank?
    return if supplier.account_id == ingredient.account_id
    errors.add(:ingredient, :wrong_account)
  end

  def refresh_ingredient_cost_cache_if_default
    # Fire when this row is default, OR when it used to be (undefaulting
    # an ingredient should re-cache from the next-default row or nil it).
    was_default = saved_change_to_is_default_cost_source?
    return unless is_default_cost_source? || was_default

    current = ingredient.supplier_ingredients.default.first
    new_cents = current&.unit_cost_cents.to_i

    # Bypass the after_commit chain on Ingredient (which enqueues a
    # RecipeCostRefreshJob) if the number didn't actually change — we
    # only want the cascade when prices moved.
    if ingredient.unit_cost_cents != new_cents
      ingredient.update!(unit_cost_cents: new_cents)
    end
  end
end
