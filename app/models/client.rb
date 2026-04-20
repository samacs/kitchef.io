# == Schema Information
#
# Table name: clients
#
#  id               :bigint           not null, primary key
#  allergies        :text
#  birthday         :date
#  city             :string
#  colonia          :string
#  discarded_at     :datetime
#  email            :string
#  first_name       :string           not null
#  last_name        :string
#  notes            :text
#  phone            :string
#  phone_normalized :string
#  references_note  :text
#  street_address   :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  index_clients_on_account_id                       (account_id)
#  index_clients_on_account_id_and_email             (account_id,email)
#  index_clients_on_account_id_and_phone_normalized  (account_id,phone_normalized)
#  index_clients_on_discarded_at                     (discarded_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Client < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "cli")
  include HasSoftDelete

  has_paper_trail

  has_person_name
  phony_normalize :phone, as: :phone_normalized, default_country_code: "MX"

  # Orders outlive their client — if an operator purges a client, we keep
  # the order history with client_id nulled so reports stay correct.
  has_many :orders, dependent: :nullify

  # Run BEFORE the strict Phonelib validator so "662 188 4355" and the
  # WhatsApp "+521 ..." variants reach validation as clean E.164.
  before_validation :normalize_phone

  validates :first_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate  :phone_is_valid_mx_number
  validates :birthday, comparison: { less_than_or_equal_to: -> { Date.current } }, allow_nil: true

  scope :search, ->(term) {
    return all if term.blank?
    where(<<~SQL, q: "%#{term.downcase}%")
      LOWER(first_name) LIKE :q
      OR LOWER(last_name) LIKE :q
      OR phone_normalized LIKE :q
      OR LOWER(email) LIKE :q
    SQL
  }

  private

  def normalize_phone
    return if phone.blank?

    normalized = Phone::NormalizeMx.call(raw: phone)
    # If we can't shape it into a local 10-digit MX number, leave the
    # raw value in place — the validator below will surface an error
    # with the operator's original input intact for correction.
    self.phone = normalized if normalized
  end

  def phone_is_valid_mx_number
    return if phone.blank?
    return if Phonelib.valid_for_country?(phone, "MX")

    errors.add(:phone, :invalid)
  end
end
