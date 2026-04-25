# == Schema Information
#
# Table name: fixed_cost_categories
#
#  id           :bigint           not null, primary key
#  discarded_at :datetime
#  kind         :integer          default("other"), not null
#  name         :string           not null
#  position     :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  idx_on_account_id_kind_position_20bc8955b1   (account_id,kind,position)
#  index_fixed_cost_categories_on_account_id    (account_id)
#  index_fixed_cost_categories_on_discarded_at  (discarded_at)
#  uniq_fixed_cost_categories_account_name      (account_id, lower((name)::text)) UNIQUE WHERE (discarded_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class FixedCostCategory < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "fcc")
  include HasSoftDelete

  KINDS = { rent: 0, utilities: 1, packaging: 2, platform: 3, other: 99 }.freeze

  enum :kind, KINDS

  # restrict_with_error: if fixed costs still point to this row the
  # operator has to close them out (or reassign) before the category can
  # be removed. Hard-deletes only run on Account#destroy, which cascades
  # in declaration order (fixed_costs tear down before categories).
  has_many :fixed_costs, dependent: :restrict_with_error

  before_validation :strip_name

  validates :name, presence: true, length: { maximum: 60 }
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }

  scope :alphabetical, -> { order(Arel.sql("LOWER(name) ASC")) }

  def self.picker_options_for(account:)
    for_account(account).kept
      .order(:position, :name)
      .pluck(:name, :id)
  end

  def usage_count
    fixed_costs.kept.count
  end

  private

  def strip_name
    self.name = name.to_s.strip if name.is_a?(String)
  end
end
