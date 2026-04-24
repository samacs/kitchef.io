# == Schema Information
#
# Table name: purchases
#
#  id                   :bigint           not null, primary key
#  currency             :string           default("MXN"), not null
#  discarded_at         :datetime
#  notes                :text
#  purchased_on         :date             not null
#  total_cents          :bigint           default(0), not null
#  total_cents_override :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  supplier_id          :bigint
#
# Indexes
#
#  index_purchases_on_account_id                   (account_id)
#  index_purchases_on_account_id_and_purchased_on  (account_id,purchased_on)
#  index_purchases_on_discarded_at                 (discarded_at)
#  index_purchases_on_supplier_id                  (supplier_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (supplier_id => suppliers.id) ON DELETE => nullify
#
class Purchase < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "pur")
  include HasSoftDelete

  has_paper_trail

  belongs_to :supplier, optional: true
  has_many :items, class_name: "PurchaseItem", dependent: :destroy, inverse_of: :purchase

  accepts_nested_attributes_for :items,
    allow_destroy: true,
    reject_if: ->(attrs) {
      attrs["ingredient_id"].blank? ||
        attrs["quantity"].blank? ||
        attrs["quantity"].to_f <= 0
    }

  # Snap-and-forget receipt. Kept as a single image (no OCR) so the
  # operator's contador has something to reconcile against.
  has_one_attached :receipt_photo do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 180, 180 ]
    attachable.variant :card,  resize_to_limit: [ 640, 640 ]
    attachable.variant :hero,  resize_to_limit: [ 1600, 1600 ]
  end

  monetize :total_cents
  monetize :total_cents_override, as: :total_override, allow_nil: true

  validates :purchased_on, presence: true
  validates :receipt_photo,
    content_type: %i[image/jpeg image/png image/webp image/heic],
    size: { less_than: 8.megabytes }
  validate  :supplier_belongs_to_same_account

  before_save :recompute_total

  scope :recent,  -> { order(purchased_on: :desc, id: :desc) }
  scope :between, ->(from, to) { where(purchased_on: from..to) }

  def item_count
    items.size
  end

  def supplier_name
    supplier&.name
  end

  def receipt_photo?
    receipt_photo.attached?
  end

  def total_matches_items?
    total_cents_override.blank?
  end

  private

  def recompute_total
    if total_cents_override.present?
      self.total_cents = total_cents_override
    else
      self.total_cents = items.reject(&:marked_for_destruction?).sum do |item|
        (BigDecimal(item.quantity.to_s) * item.unit_cost_cents).to_i
      end
    end
  end

  def supplier_belongs_to_same_account
    return if supplier.blank? || account_id.blank?
    return if supplier.account_id == account_id
    errors.add(:supplier, :wrong_account)
  end
end
