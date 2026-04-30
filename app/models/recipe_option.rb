# == Schema Information
#
# Table name: recipe_options
#
#  id                     :bigint           not null, primary key
#  color_hex              :string
#  componentable_type     :string
#  cost_delta_cents       :bigint           default(0), not null
#  discarded_at           :datetime
#  is_default             :boolean          default(FALSE), not null
#  label                  :string           not null
#  position               :integer
#  price_delta_cents      :bigint           default(0), not null
#  quantity               :decimal(10, 3)
#  sub                    :string
#  unit                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  componentable_id       :bigint
#  recipe_option_group_id :bigint           not null
#
# Indexes
#
#  idx_recipe_options_componentable                             (componentable_type,componentable_id)
#  index_recipe_options_on_discarded_at                         (discarded_at)
#  index_recipe_options_on_recipe_option_group_id               (recipe_option_group_id)
#  index_recipe_options_on_recipe_option_group_id_and_position  (recipe_option_group_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (recipe_option_group_id => recipe_option_groups.id)
#
class RecipeOption < ApplicationRecord
  include HasPrefixedId.new(prefix: "roo")
  include HasSoftDelete

  has_paper_trail
  positioned on: :recipe_option_group

  monetize :price_delta_cents, allow_nil: false
  monetize :cost_delta_cents, allow_nil: false

  belongs_to :recipe_option_group
  belongs_to :componentable, polymorphic: true, optional: true

  validates :label, presence: true, length: { maximum: 120 }
  validates :price_delta_cents, numericality: { only_integer: true }
  validates :color_hex,
    format: { with: /\A#[0-9a-fA-F]{6}\z/ },
    allow_blank: true
  validates :quantity,
    numericality: { greater_than: 0 },
    presence: true,
    if: :inventory_linked?
  validates :unit,
    presence: true,
    if: :inventory_linked?
  validate :single_default_for_radio_and_swatch
  validate :componentable_type_is_valid
  validate :componentable_same_account
  validate :unit_compatible_with_componentable
  validate :no_cycle_with_recipe_componentable

  delegate :kind, :recipe, to: :recipe_option_group

  after_commit :enqueue_cost_delta_refresh, on: %i[create update],
    if: :inventory_linked?

  def inventory_linked?
    componentable_id.present?
  end

  def componentable_canonical_unit
    case componentable
    when Ingredient then componentable.unit
    when Recipe     then componentable.yield_unit
    end
  end

  private

  def single_default_for_radio_and_swatch
    return unless is_default?
    return unless recipe_option_group&.kind&.in?(%w[radio swatch])

    siblings = recipe_option_group.options.where(is_default: true)
    siblings = siblings.where.not(id: id) if persisted?
    return if siblings.none?

    errors.add(:is_default, :single_default)
  end

  def componentable_type_is_valid
    return if componentable_type.blank?
    return if componentable_type.in?(%w[Ingredient Recipe])

    errors.add(:componentable_type, :invalid)
  end

  def componentable_same_account
    return unless inventory_linked?
    return unless componentable.respond_to?(:account_id)
    return unless recipe_option_group&.recipe

    return if componentable.account_id == recipe_option_group.recipe.account_id

    errors.add(:componentable, :cross_account)
  end

  def unit_compatible_with_componentable
    return unless inventory_linked?

    canonical = componentable_canonical_unit
    return if canonical.blank? || unit.blank?
    return if Recipes::UnitConverter.compatible?(unit, canonical)

    errors.add(:unit, :incompatible)
  end

  def no_cycle_with_recipe_componentable
    return unless inventory_linked?
    return unless componentable_type == "Recipe"
    return unless recipe_option_group&.recipe

    parent = recipe_option_group.recipe
    return if componentable_id == parent.id && errors.add(:componentable, :self_reference).present?
    return unless Recipes::CycleDetector.would_cycle?(parent: parent, candidate: componentable)

    errors.add(:componentable, :cycle)
  end

  def enqueue_cost_delta_refresh
    RecipeCostRefreshJob.perform_later(recipe_id: recipe_option_group.recipe_id)
  end
end
