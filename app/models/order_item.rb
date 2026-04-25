# == Schema Information
#
# Table name: order_items
#
#  id               :bigint           not null, primary key
#  notes            :text
#  position         :integer
#  quantity         :decimal(10, 3)   default(1.0), not null
#  unit_cost_cents  :bigint           default(0), not null
#  unit_price_cents :bigint           default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  order_id         :bigint           not null
#  recipe_id        :bigint           not null
#
# Indexes
#
#  index_order_items_on_order_id               (order_id)
#  index_order_items_on_order_id_and_position  (order_id,position)
#  index_order_items_on_recipe_id              (recipe_id)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#  fk_rails_...  (recipe_id => recipes.id)
#
class OrderItem < ApplicationRecord
  positioned on: :order

  monetize :unit_price_cents
  monetize :unit_cost_cents

  belongs_to :order
  belongs_to :recipe

  before_validation :snapshot_costs, on: :create

  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_cents, :unit_cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate  :recipe_is_saleable

  def line_total
    Money.new((unit_price_cents * quantity).to_i, "MXN")
  end

  private

  # Belt-and-suspenders snapshot for any path that creates an item outside
  # of the Orders::Place command (e.g. console, console fix-ups). The
  # command sets prices/costs explicitly; only blank attributes get filled.
  # Recipe-level packaging (e.g. the caja for a pastel) is baked into the
  # cost snapshot so reports see it through the same surface they already
  # read — `unit_cost_cents * quantity`.
  def snapshot_costs
    return if recipe.nil?

    self.unit_price_cents = recipe.sale_price_cents if unit_price_cents.to_i.zero?
    if unit_cost_cents.to_i.zero?
      self.unit_cost_cents = recipe.cost_cents_cached.to_i + recipe.packaging_cents.to_i
    end
  end

  def recipe_is_saleable
    return if recipe.nil? || recipe.is_saleable?

    errors.add(:recipe, :not_saleable)
  end
end
