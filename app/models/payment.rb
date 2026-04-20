# == Schema Information
#
# Table name: payments
#
#  id           :bigint           not null, primary key
#  amount_cents :bigint           default(0), not null
#  method       :integer          default("cash"), not null
#  notes        :text
#  received_at  :datetime         not null
#  reference    :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  order_id     :bigint           not null
#
# Indexes
#
#  index_payments_on_order_id                  (order_id)
#  index_payments_on_order_id_and_received_at  (order_id,received_at)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#
class Payment < ApplicationRecord
  include HasPrefixedId.new(prefix: "pay")

  monetize :amount_cents

  # Payment methods. `mercado_pago` keeps the brand name; everything else is
  # a generic English identifier. Display strings live under
  # `t("payment.methods.*")` in config/locales/es-MX/domain.yml.
  METHODS = {
    cash:         0,
    transfer:     1,
    card:         2,
    mercado_pago: 3,
    other:       99
  }.freeze

  enum :method, METHODS, prefix: true

  belongs_to :order

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :received_at,  presence: true
end
