# == Schema Information
#
# Table name: ingredients
#
#  id                     :bigint           not null, primary key
#  currency               :string           default("MXN"), not null
#  discarded_at           :datetime
#  last_purchase_quantity :decimal(12, 3)
#  low_stock_alert_at     :datetime
#  name                   :string           not null
#  notes                  :text
#  position               :integer
#  price_updated_at       :datetime
#  stock_quantity         :decimal(12, 3)   default(0.0), not null
#  stock_updated_at       :datetime
#  supplier_name          :string
#  unit                   :string           not null
#  unit_cost_cents        :bigint           default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  category_id            :bigint           not null
#
# Indexes
#
#  index_ingredients_on_account_id                               (account_id)
#  index_ingredients_on_account_id_and_category_id_and_position  (account_id,category_id,position)
#  index_ingredients_on_account_id_and_name                      (account_id,name)
#  index_ingredients_on_category_id                              (category_id)
#  index_ingredients_on_discarded_at                             (discarded_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (category_id => categories.id)
#
class Ingredient < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "ing")
  include HasSoftDelete

  has_paper_trail
  positioned on: [ :account, :category_id ]
  monetize :unit_cost_cents

  UNITS = %w[g kg ml l piece].freeze

  belongs_to :category

  # Destroy cascades — this matches "delete the whole kitchen" semantics.
  # Per-ingredient deletion in the UI is guarded at the controller level
  # (warn the operator about affected recipes), not at the model level.
  has_many :recipe_components, as: :componentable, dependent: :destroy
  has_many :recipes_using,     through: :recipe_components, source: :recipe

  # Phase 9: per-supplier price rows. `unit_cost_cents` on this record
  # becomes a write-through cache of the default row (see
  # `SupplierIngredient#refresh_ingredient_cost_cache_if_default`).
  has_many :supplier_ingredients, dependent: :destroy
  has_many :suppliers, through: :supplier_ingredients
  has_many :purchase_items, dependent: :destroy

  has_one :default_supplier_ingredient,
    -> { where(is_default_cost_source: true) },
    class_name: "SupplierIngredient"
  has_one :default_supplier, through: :default_supplier_ingredient, source: :supplier

  has_many :stock_movements, dependent: :destroy

  validates :name, presence: true, length: { maximum: 80 }
  validates :unit, presence: true, inclusion: { in: UNITS }
  validates :unit_cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate  :category_belongs_to_same_account

  before_save :stamp_price_updated_at, if: :unit_cost_cents_changed?
  after_commit :enqueue_cost_refresh, on: :update, if: :saved_change_to_unit_cost_cents?

  scope :by_category, ->(category_id) { where(category_id: category_id) }

  # Phase 13 — true when the on-hand quantity has dropped below the
  # operator-configured percentage of her last purchase. Returns false
  # for accounts with inventory disabled (the chip is hidden anyway)
  # and for ingredients we've never seen a purchase quantity for.
  def low_stock?
    return false unless account.inventory_enabled?
    return false if last_purchase_quantity.to_d.zero?

    pct = account.inventory_settings.low_stock_threshold_pct.to_i
    threshold = last_purchase_quantity.to_d * pct / 100
    stock_quantity.to_d < threshold
  end

  # Add to on-hand stock. Quantity is converted into the ingredient's
  # canonical unit before the column is updated, so a "5 kg" purchase
  # of a kg-tracked ingredient lands as +5; a "500 g" purchase of the
  # same ingredient lands as +0.5. Returns the resulting StockMovement.
  #
  # `source` must be one of StockMovement::SOURCES. `source_record` is
  # optional but strongly recommended — it lets the audit trail
  # deep-link back to the originating Purchase / ProductionRun / Order.
  def restock!(quantity:, unit:, source:, source_record: nil, note: nil, unit_cost_cents: nil)
    apply_movement!(
      delta:          BigDecimal(quantity.to_s),
      delta_unit:     unit.to_s,
      source:         source.to_s,
      source_record:  source_record,
      note:           note,
      unit_cost_cents: unit_cost_cents
    )
  end

  # Subtract from on-hand stock. Negative balances are allowed (the
  # operator may have miscounted the pantry — we'd rather log the
  # discrepancy and let her reconcile than block her cooking).
  def deplete!(quantity:, unit:, source:, source_record: nil, note: nil, unit_cost_cents: nil)
    apply_movement!(
      delta:          -BigDecimal(quantity.to_s),
      delta_unit:     unit.to_s,
      source:         source.to_s,
      source_record:  source_record,
      note:           note,
      unit_cost_cents: unit_cost_cents
    )
  end

  def category_name
    category&.name
  end

  private

  def apply_movement!(delta:, delta_unit:, source:, source_record:, note:, unit_cost_cents:)
    canonical_delta = Recipes::UnitConverter.convert(
      quantity: delta.abs,
      from:     delta_unit,
      to:       unit
    )
    canonical_delta = -canonical_delta if delta.negative?

    movement = nil
    transaction do
      new_stock = stock_quantity.to_d + canonical_delta
      update!(stock_quantity: new_stock, stock_updated_at: Time.current)
      movement = stock_movements.create!(
        account:                     account,
        quantity:                    canonical_delta,
        unit:                        unit,
        source:                      source,
        source_record:               source_record,
        note:                        note,
        unit_cost_cents_at_movement: unit_cost_cents || self.unit_cost_cents
      )
    end
    movement
  end

  public

  def category_belongs_to_same_account
    return if category.blank? || account_id.blank?
    return if category.account_id == account_id
    errors.add(:category, :wrong_account)
  end

  def stamp_price_updated_at
    self.price_updated_at = Time.current
  end

  def enqueue_cost_refresh
    RecipeCostRefreshJob.perform_later(
      componentable_type: "Ingredient",
      componentable_id:   id
    )
  end
end
