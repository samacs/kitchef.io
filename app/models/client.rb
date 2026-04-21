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
#  index_clients_on_account_id            (account_id)
#  index_clients_on_account_id_and_email  (account_id,email)
#  index_clients_on_discarded_at          (discarded_at)
#  uniq_clients_account_phone_active      (account_id,phone_normalized) UNIQUE WHERE ((phone_normalized IS NOT NULL) AND (discarded_at IS NULL))
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

  # Storefront dedup entry point. Phone is the identity — storefront
  # checkout only captures first_name + last_name + phone, so matching
  # on `(account, phone_normalized)` is how we keep one client record per
  # customer across repeat pedidos.
  #
  # Never overwrites existing first_name/last_name on a subsequent order
  # (the customer might use "Lupita" on one pedido and "Guadalupe Ramírez"
  # on the next; the operator's roster should keep whatever she first
  # chose). Blank names ARE backfilled — useful if the client was
  # autocreated from an earlier manual pedido with only a phone.
  #
  # The unique partial index `uniq_clients_account_phone_active` is what
  # makes this race-free under concurrent storefront submissions.
  def self.find_or_create_by_phone!(account:, phone:, attrs: {})
    normalized = Phone::NormalizeMx.call(raw: phone)
    raise ArgumentError, "phone could not be normalized" if normalized.blank?

    existing = account.clients.kept.find_by(phone_normalized: normalized)
    if existing
      updates = {}
      updates[:first_name] = attrs[:first_name] if existing.first_name.blank? && attrs[:first_name].present?
      updates[:last_name]  = attrs[:last_name]  if existing.last_name.blank?  && attrs[:last_name].present?
      updates[:email]      = attrs[:email]      if existing.email.blank?      && attrs[:email].present?
      existing.update!(updates) if updates.any?
      return existing
    end

    account.clients.create!(
      first_name: attrs[:first_name].presence || "Cliente",
      last_name:  attrs[:last_name].presence,
      email:      attrs[:email].presence,
      phone:      normalized
    )
  rescue ActiveRecord::RecordNotUnique
    # Lost the race — another request inserted the same (account, phone).
    # Re-read and return it.
    account.clients.kept.find_by!(phone_normalized: normalized)
  end


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
