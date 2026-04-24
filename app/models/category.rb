# == Schema Information
#
# Table name: categories
#
#  id           :bigint           not null, primary key
#  discarded_at :datetime
#  kind         :integer          default("ingredient"), not null
#  name         :string           not null
#  position     :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_categories_on_account_id                        (account_id)
#  index_categories_on_account_id_and_kind_and_position  (account_id,kind,position)
#  index_categories_on_discarded_at                      (discarded_at)
#  uniq_categories_account_kind_name                     (account_id, kind, lower((name)::text)) UNIQUE WHERE (discarded_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Category < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "cat")
  include HasSoftDelete

  KINDS = { ingredient: 0, recipe: 1 }.freeze

  enum :kind, KINDS

  # Manually managed position column (no Positioning gem here — the
  # gem's scope machinery trips the enum + unique index combo; a plain
  # column + `.order(:position, :name)` lookups are enough for what
  # little reordering the v1 UI exposes).

  # restrict_with_error: the UI lets the operator soft-delete a category
  # only after reassigning every linked ingredient/recipe. Hard-deletes
  # only happen on Account#destroy, which cascades in the declared order
  # (ingredients/recipes die first, then categories).
  has_many :ingredients, dependent: :restrict_with_error
  has_many :recipes,     dependent: :restrict_with_error

  before_validation :strip_name

  validates :name, presence: true, length: { maximum: 60 }
  validates :name, uniqueness: { scope: [ :account_id, :kind ], case_sensitive: false }

  scope :for_kind, ->(k) { where(kind: k) }
  scope :alphabetical, -> { order(Arel.sql("LOWER(name) ASC")) }

  # Returns [label, id] pairs ready for a <select> or the
  # Ui::ComboboxComponent `options:` arg.
  def self.picker_options_for(account:, kind:)
    for_account(account).for_kind(kind).kept
      .order(:position, :name)
      .pluck(:name, :id)
  end

  def usage_count
    ingredient? ? ingredients.kept.count : recipes.kept.count
  end

  private

  def strip_name
    self.name = name.to_s.strip if name.is_a?(String)
  end
end
