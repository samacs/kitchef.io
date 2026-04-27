# == Schema Information
#
# Table name: stock_movements
#
#  id                          :bigint           not null, primary key
#  note                        :text
#  quantity                    :decimal(14, 3)   not null
#  source                      :string           not null
#  source_type                 :string
#  unit                        :string           not null
#  unit_cost_cents_at_movement :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#  ingredient_id               :bigint           not null
#  source_id                   :bigint
#
# Indexes
#
#  idx_stock_movements_account_ingredient_time  (account_id,ingredient_id,created_at)
#  idx_stock_movements_source                   (source_type,source_id)
#  index_stock_movements_on_account_id          (account_id)
#  index_stock_movements_on_ingredient_id       (ingredient_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ingredient_id => ingredients.id)
#
class StockMovement < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "mov")

  # Append-only ledger of every change to an ingredient's `stock_quantity`.
  # Created by Ingredient#restock! / Ingredient#deplete!; never updated
  # or deleted by application code. Reading the table backwards from
  # current stock should reconstruct the on-hand history at any point in
  # time — that's the variance-report foundation for Phase 13.5.

  SOURCES = %w[
    purchase
    production_deplete
    production_cancel
    order_consume
    order_restock
    manual_adjust
    initial
  ].freeze

  belongs_to :ingredient
  belongs_to :source_record, polymorphic: true,
    foreign_key: :source_id, foreign_type: :source_type, optional: true

  validates :quantity, numericality: true
  validates :unit, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }

  scope :positive, -> { where(arel_table[:quantity].gt(0)) }
  scope :negative, -> { where(arel_table[:quantity].lt(0)) }
  scope :recent,   -> { order(created_at: :desc) }

  def restock?
    quantity.to_d.positive?
  end

  def deplete?
    quantity.to_d.negative?
  end
end
