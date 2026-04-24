# == Schema Information
#
# Table name: purchase_items
#
#  id              :bigint           not null, primary key
#  currency        :string           default("MXN"), not null
#  notes           :text
#  position        :integer
#  quantity        :decimal(10, 3)   not null
#  unit            :string           not null
#  unit_cost_cents :bigint           default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ingredient_id   :bigint           not null
#  purchase_id     :bigint           not null
#
# Indexes
#
#  index_purchase_items_on_ingredient_id             (ingredient_id)
#  index_purchase_items_on_purchase_id               (purchase_id)
#  index_purchase_items_on_purchase_id_and_position  (purchase_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (ingredient_id => ingredients.id) ON DELETE => cascade
#  fk_rails_...  (purchase_id => purchases.id) ON DELETE => cascade
#
class PurchaseItem < ApplicationRecord
  belongs_to :purchase, inverse_of: :items
  belongs_to :ingredient

  monetize :unit_cost_cents

  positioned on: :purchase

  validates :quantity, numericality: { greater_than: 0 }
  validates :unit,     presence: true, inclusion: { in: Ingredient::UNITS }
  validates :unit_cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate  :ingredient_belongs_to_purchase_account

  def subtotal_cents
    (BigDecimal(quantity.to_s) * unit_cost_cents).to_i
  end

  def subtotal
    Money.new(subtotal_cents, currency)
  end

  # Unit cost expressed in the ingredient's canonical storage unit, so
  # the SupplierIngredient snapshot stays comparable across purchases.
  # A 1 kg purchase at $32 stored as grams becomes $0.032/g; a 500 g
  # bag at the same price becomes $0.064/g.
  def unit_cost_cents_in_ingredient_unit
    return unit_cost_cents if unit == ingredient.unit

    qty_in_canonical = Recipes::UnitConverter.convert(
      quantity: BigDecimal("1"),
      from: unit,
      to: ingredient.unit
    )
    # We need the inverse — "what would 1 canonical unit cost me?"
    (BigDecimal(unit_cost_cents.to_s) / qty_in_canonical).to_i
  rescue Recipes::UnitConverter::IncompatibleUnits
    unit_cost_cents
  end

  private

  def ingredient_belongs_to_purchase_account
    return if ingredient.blank? || purchase.blank?
    return if ingredient.account_id == purchase.account_id
    errors.add(:ingredient, :wrong_account)
  end
end
