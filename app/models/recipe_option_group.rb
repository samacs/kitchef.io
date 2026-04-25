# == Schema Information
#
# Table name: recipe_option_groups
#
#  id           :bigint           not null, primary key
#  discarded_at :datetime
#  kind         :integer          default("radio"), not null
#  label        :string           not null
#  max_length   :integer
#  position     :integer
#  required     :boolean          default(FALSE), not null
#  sub          :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  recipe_id    :bigint           not null
#
# Indexes
#
#  index_recipe_option_groups_on_account_id              (account_id)
#  index_recipe_option_groups_on_discarded_at            (discarded_at)
#  index_recipe_option_groups_on_recipe_id               (recipe_id)
#  index_recipe_option_groups_on_recipe_id_and_position  (recipe_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (recipe_id => recipes.id)
#
class RecipeOptionGroup < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "rog")
  include HasSoftDelete

  has_paper_trail
  positioned on: :recipe

  KINDS = { radio: 0, check: 1, swatch: 2, textarea: 3 }.freeze

  enum :kind, KINDS

  belongs_to :recipe

  has_many :options,
    class_name: "RecipeOption",
    dependent: :destroy,
    inverse_of: :recipe_option_group

  accepts_nested_attributes_for :options,
    allow_destroy: true,
    reject_if: ->(attrs) { attrs["label"].blank? }

  validates :label, presence: true, length: { maximum: 120 }
  validates :kind, presence: true
  validates :max_length,
    numericality: { only_integer: true, greater_than: 0 },
    allow_nil: true
  validate :account_matches_recipe

  private

  def account_matches_recipe
    return if recipe.blank? || account_id.blank?
    return if recipe.account_id == account_id

    errors.add(:account, :mismatch)
  end
end
