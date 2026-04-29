# == Schema Information
#
# Table name: promotion_redemptions
#
#  id             :bigint           not null, primary key
#  discount_cents :bigint           default(0), not null
#  discount_label :string           not null
#  kind           :integer          default("automatic"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  client_id      :bigint
#  order_id       :bigint           not null
#  promotion_id   :bigint           not null
#
# Indexes
#
#  idx_promotion_client_redemptions             (promotion_id,client_id)
#  index_promotion_redemptions_on_client_id     (client_id)
#  index_promotion_redemptions_on_order_id      (order_id)
#  index_promotion_redemptions_on_promotion_id  (promotion_id)
#  uniq_redemption_per_kind                     (order_id,kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id) ON DELETE => nullify
#  fk_rails_...  (order_id => orders.id)
#  fk_rails_...  (promotion_id => promotions.id)
#
class PromotionRedemption < ApplicationRecord
  KINDS = { automatic: 0, coupon: 1 }.freeze

  enum :kind, KINDS, prefix: true

  belongs_to :promotion
  belongs_to :order
  belongs_to :client, optional: true

  monetize :discount_cents

  validates :discount_cents, numericality: { greater_than: 0 }
  validates :discount_label, presence: true
  validates :kind, uniqueness: { scope: :order_id }
end
