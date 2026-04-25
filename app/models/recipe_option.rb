# == Schema Information
#
# Table name: recipe_options
#
#  id                     :bigint           not null, primary key
#  color_hex              :string
#  discarded_at           :datetime
#  is_default             :boolean          default(FALSE), not null
#  label                  :string           not null
#  position               :integer
#  price_delta_cents      :bigint           default(0), not null
#  sub                    :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  recipe_option_group_id :bigint           not null
#
# Indexes
#
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

  belongs_to :recipe_option_group

  validates :label, presence: true, length: { maximum: 120 }
  validates :price_delta_cents, numericality: { only_integer: true }
  validates :color_hex,
    format: { with: /\A#[0-9a-fA-F]{6}\z/ },
    allow_blank: true
  validate :single_default_for_radio_and_swatch

  delegate :kind, :recipe, to: :recipe_option_group

  private

  def single_default_for_radio_and_swatch
    return unless is_default?
    return unless recipe_option_group&.kind&.in?(%w[radio swatch])

    siblings = recipe_option_group.options.where(is_default: true)
    siblings = siblings.where.not(id: id) if persisted?
    return if siblings.none?

    errors.add(:is_default, :single_default)
  end
end
