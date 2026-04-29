# == Schema Information
#
# Table name: promotions
#
#  id                 :bigint           not null, primary key
#  active             :boolean          default(TRUE), not null
#  bogo_buy_quantity  :integer          default(1)
#  bogo_get_quantity  :integer          default(1)
#  code               :string
#  discarded_at       :datetime
#  discount_type      :integer          default("percentage"), not null
#  discount_value     :integer          not null
#  ends_at            :datetime
#  kind               :integer          default("automatic"), not null
#  max_discount_cents :bigint
#  min_order_cents    :bigint           default(0), not null
#  name               :string           not null
#  per_client_limit   :integer
#  priority           :integer          default(0), not null
#  scope_type         :integer          default("order"), not null
#  starts_at          :datetime
#  total_usage_count  :integer          default(0), not null
#  total_usage_limit  :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#
# Indexes
#
#  idx_promotions_account_active_kind  (account_id,active,kind)
#  index_promotions_on_account_id      (account_id)
#  index_promotions_on_discarded_at    (discarded_at)
#  uniq_promotions_account_code        (account_id,code) UNIQUE WHERE ((code IS NOT NULL) AND (discarded_at IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Promotion < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "prm")
  include HasSoftDelete

  KINDS          = { automatic: 0, coupon: 1 }.freeze
  DISCOUNT_TYPES = { percentage: 0, fixed_amount: 1, bogo: 2 }.freeze
  SCOPE_TYPES    = { order: 0, recipe: 1, category: 2 }.freeze

  enum :kind,          KINDS,          prefix: true
  enum :discount_type, DISCOUNT_TYPES, prefix: true
  enum :scope_type,    SCOPE_TYPES,    prefix: true

  has_many :promotion_recipes,    dependent: :destroy
  has_many :recipes,              through: :promotion_recipes
  has_many :promotion_categories, dependent: :destroy
  has_many :categories,           through: :promotion_categories
  has_many :redemptions, class_name: "PromotionRedemption",
    dependent: :restrict_with_error

  accepts_nested_attributes_for :promotion_recipes, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :promotion_categories, allow_destroy: true, reject_if: :all_blank

  monetize :min_order_cents
  monetize :max_discount_cents, allow_nil: true

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, if: :kind_coupon?
  validates :code,
    uniqueness: { scope: :account_id, case_sensitive: false },
    format: { with: /\A[A-Z0-9\-_]{3,20}\z/i },
    allow_nil: true
  validates :discount_value, presence: true,
    numericality: { greater_than: 0 }
  validates :discount_value,
    numericality: { less_than_or_equal_to: 100 },
    if: :discount_type_percentage?
  validates :bogo_buy_quantity, :bogo_get_quantity,
    numericality: { greater_than: 0, only_integer: true },
    if: :discount_type_bogo?
  validate :bogo_requires_item_scope
  validate :date_range_coherent
  validate :scope_records_present

  scope :active_now, -> {
    kept.where(active: true)
      .where("starts_at IS NULL OR starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
  }
  scope :automatic, -> { where(kind: :automatic) }
  scope :coupons,   -> { where(kind: :coupon) }
  scope :by_priority, -> { order(priority: :asc, created_at: :asc) }

  before_validation :upcase_code

  def expired?
    ends_at.present? && ends_at < Time.current
  end

  def usage_limit_reached?
    total_usage_limit.present? && total_usage_count >= total_usage_limit
  end

  def client_limit_reached?(client)
    return false if per_client_limit.nil? || client.nil?
    redemptions.where(client: client).count >= per_client_limit
  end

  def eligible?(subtotal_cents:, client: nil)
    return false unless active? && !discarded?
    return false if expired?
    return false if usage_limit_reached?
    return false if client_limit_reached?(client)
    return false if subtotal_cents < min_order_cents
    true
  end

  def discount_type_label
    I18n.t("promotions.discount_types.#{discount_type}")
  end

  def kind_label
    I18n.t("promotions.kinds.#{kind}")
  end

  def scope_type_label
    I18n.t("promotions.scope_types.#{scope_type}")
  end

  private

  def upcase_code
    self.code = code&.strip&.upcase
  end

  def bogo_requires_item_scope
    return unless discount_type_bogo? && scope_type_order?
    errors.add(:scope_type, :bogo_requires_item_scope)
  end

  def date_range_coherent
    return if starts_at.blank? || ends_at.blank?
    return if ends_at >= starts_at
    errors.add(:ends_at, :before_starts_at)
  end

  def scope_records_present
    if scope_type_recipe? && promotion_recipes.reject(&:marked_for_destruction?).empty?
      errors.add(:recipes, :required_for_scope)
    end
    if scope_type_category? && promotion_categories.reject(&:marked_for_destruction?).empty?
      errors.add(:categories, :required_for_scope)
    end
  end
end
