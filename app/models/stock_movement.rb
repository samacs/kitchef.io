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
