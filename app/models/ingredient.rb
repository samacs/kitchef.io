# == Schema Information
#
# Table name: ingredients
#
#  id               :bigint           not null, primary key
#  category         :integer          default("pantry"), not null
#  currency         :string           default("MXN"), not null
#  discarded_at     :datetime
#  name             :string           not null
#  notes            :text
#  position         :integer
#  price_updated_at :datetime
#  supplier_name    :string
#  unit             :string           not null
#  unit_cost_cents  :bigint           default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  index_ingredients_on_account_id                            (account_id)
#  index_ingredients_on_account_id_and_category_and_position  (account_id,category,position)
#  index_ingredients_on_account_id_and_name                   (account_id,name)
#  index_ingredients_on_discarded_at                          (discarded_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Ingredient < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "ing")
  include HasSoftDelete

  has_paper_trail
  positioned on: [ :account, :category ]
  monetize :unit_cost_cents

  UNITS      = %w[g kg ml l piece].freeze
  CATEGORIES = {
    pantry:  0,
    meats:   1,
    dairy:   2,
    produce: 3,
    spices:  4,
    other:  99
  }.freeze

  enum :category, CATEGORIES, prefix: true

  # Destroy cascades — this matches "delete the whole kitchen" semantics.
  # Per-ingredient deletion in the UI is guarded at the controller level
  # (warn the operator about affected recipes), not at the model level.
  has_many :recipe_components, as: :componentable, dependent: :destroy
  has_many :recipes_using,     through: :recipe_components, source: :recipe

  validates :name, presence: true, length: { maximum: 80 }
  validates :unit, presence: true, inclusion: { in: UNITS }
  validates :unit_cost_cents, numericality: { greater_than_or_equal_to: 0 }

  before_save :stamp_price_updated_at, if: :unit_cost_cents_changed?
  after_commit :enqueue_cost_refresh, on: :update, if: :saved_change_to_unit_cost_cents?

  scope :by_category, ->(category) { where(category: category) }

  private

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
