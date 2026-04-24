# == Schema Information
#
# Table name: recipes
#
#  id                    :bigint           not null, primary key
#  cost_cents_cached     :bigint
#  description           :text
#  discarded_at          :datetime
#  is_published          :boolean          default(FALSE), not null
#  is_saleable           :boolean          default(TRUE), not null
#  name                  :string           not null
#  position              :integer
#  sale_price_cents      :bigint           default(0), not null
#  slug                  :string           not null
#  target_margin_percent :integer          default(60), not null
#  yield_quantity        :decimal(10, 3)   default(1.0), not null
#  yield_unit            :string           default("porcion"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  category_id           :bigint           not null
#
# Indexes
#
#  index_recipes_on_account_id                               (account_id)
#  index_recipes_on_account_id_and_category_id_and_position  (account_id,category_id,position)
#  index_recipes_on_account_id_and_is_saleable               (account_id,is_saleable)
#  index_recipes_on_account_id_and_slug                      (account_id,slug) UNIQUE
#  index_recipes_on_category_id                              (category_id)
#  index_recipes_on_discarded_at                             (discarded_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (category_id => categories.id)
#
class Recipe < ApplicationRecord
  extend FriendlyId
  include AccountScoped
  include HasPrefixedId.new(prefix: "rec")
  include HasSoftDelete

  friendly_id :name, use: :scoped, scope: :account
  has_paper_trail
  positioned on: [ :account, :category_id ]
  monetize :sale_price_cents
  monetize :cost_cents_cached, as: :cost_cached, allow_nil: true

  YIELD_UNITS = %w[piece g kg ml l serving].freeze

  belongs_to :category

  # Components — the polymorphic join that enables decomposition. A parent
  # Recipe has many components, each pointing at either an Ingredient or
  # another Recipe.
  has_many :components,
    class_name: "RecipeComponent",
    dependent: :destroy,
    inverse_of: :recipe

  has_many :component_recipes,     through: :components, source: :componentable, source_type: "Recipe"
  has_many :component_ingredients, through: :components, source: :componentable, source_type: "Ingredient"

  # Accepts nested attributes from the decomposition form. `reject_if`
  # drops fully blank rows so the form can render an empty "+ agregar"
  # placeholder without creating a bogus row on submit.
  accepts_nested_attributes_for :components,
    allow_destroy: true,
    reject_if: ->(attrs) {
      attrs["componentable_type"].blank? ||
        attrs["componentable_id"].blank? ||
        attrs["quantity"].blank?
    }

  # Reverse side — where is this recipe used as a component?
  # Destroy cascades so an Account.destroy can proceed; UI-level deletion
  # warns the operator about affected parent recipes.
  has_many :usages,
    class_name: "RecipeComponent",
    as: :componentable,
    dependent: :destroy

  has_many_attached :photos do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 120, 120 ]
    attachable.variant :card,  resize_to_limit: [ 400, 400 ]
    attachable.variant :hero,  resize_to_limit: [ 1200, 800 ]
  end

  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true
  validates :yield_quantity, numericality: { greater_than: 0 }
  validates :yield_unit, presence: true, inclusion: { in: YIELD_UNITS }
  validates :target_margin_percent, numericality: { in: 0..100 }
  validates :sale_price_cents,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true,
    if: :is_saleable?
  validates :photos,
    content_type: %i[image/jpeg image/png image/webp image/heic],
    size: { less_than: 5.megabytes }
  validate :published_requires_saleable
  validate :category_belongs_to_same_account

  scope :saleable, -> { where(is_saleable: true) }
  scope :internal, -> { where(is_saleable: false) }
  scope :published, -> { where(is_saleable: true, is_published: true) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }

  # Candidates a given recipe could use as a component without creating a
  # cycle. Filters out itself plus any recipe whose tree already reaches
  # back to it. Used by the decomposition form's picker.
  scope :usable_as_component_for, ->(parent) {
    forbidden = [ parent.id ].compact
    return kept if forbidden.empty?

    forbidden += Recipes::DependencyGraph.recipes_depending_on(componentable: parent).ids

    kept.where.not(id: forbidden.uniq)
  }

  def internal?
    !is_saleable?
  end

  def display_photo
    photos.first&.variant(:card)
  end

  def should_generate_new_friendly_id?
    slug.blank? || will_save_change_to_name?
  end

  def category_name
    category&.name
  end

  private

  def published_requires_saleable
    return unless is_published?
    return if is_saleable?

    errors.add(:is_published, :requires_saleable)
  end

  def category_belongs_to_same_account
    return if category.blank? || account_id.blank?
    return if category.account_id == account_id
    errors.add(:category, :wrong_account)
  end
end
