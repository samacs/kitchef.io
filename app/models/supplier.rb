# == Schema Information
#
# Table name: suppliers
#
#  id                  :bigint           not null, primary key
#  city                :string
#  colonia             :string
#  discarded_at        :datetime
#  geocoded_at         :datetime
#  geocoding_failed_at :datetime
#  latitude            :decimal(10, 6)
#  longitude           :decimal(10, 6)
#  name                :string           not null
#  notes               :text
#  phone               :string
#  phone_normalized    :string
#  rfc                 :string
#  street_address      :string
#  whatsapp            :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  idx_suppliers_name_trgm                 (name) USING gin
#  index_suppliers_on_account_id           (account_id)
#  index_suppliers_on_account_id_and_name  (account_id,name)
#  index_suppliers_on_account_id_and_rfc   (account_id,rfc) WHERE (rfc IS NOT NULL)
#  index_suppliers_on_discarded_at         (discarded_at)
#  uniq_suppliers_account_phone_active     (account_id,phone_normalized) UNIQUE WHERE ((phone_normalized IS NOT NULL) AND (discarded_at IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Supplier < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "sup")
  include HasSoftDelete
  include HasRfc
  include Geocodable
  include Searchable

  searchable_on :name

  geocodable_by :street_address, :colonia, :city

  has_paper_trail

  phony_normalize :phone, as: :phone_normalized, default_country_code: "MX"
  phony_normalize :whatsapp, as: :whatsapp_normalized, default_country_code: "MX" if column_names.include?("whatsapp_normalized")

  # Cascade:destroy — tearing down an Account removes each supplier and
  # each SupplierIngredient via the `on_delete: :cascade` on the FK.
  has_many :supplier_ingredients, dependent: :destroy
  has_many :ingredients, through: :supplier_ingredients
  has_many :purchases, dependent: :nullify

  before_validation :normalize_phone

  validates :name, presence: true, length: { maximum: 80 }
  validate :phone_is_valid_mx_number
  validates :phone_normalized,
    uniqueness: { scope: :account_id, allow_nil: true, conditions: -> { kept } }

  scope :search, ->(term) {
    return all if term.blank?
    where(<<~SQL, q: "%#{term.downcase}%")
      LOWER(name) LIKE :q
      OR phone_normalized LIKE :q
      OR LOWER(colonia) LIKE :q
      OR LOWER(city) LIKE :q
      OR LOWER(rfc) LIKE :q
    SQL
  }

  def display_phone
    return nil if phone.blank?
    Phonelib.parse(phone, "MX").international.presence || phone
  end

  def ingredient_count
    supplier_ingredients.count
  end

  def last_bought_on
    supplier_ingredients.maximum(:last_bought_on)
  end

  private

  def normalize_phone
    return if phone.blank?
    normalized = Phone::NormalizeMx.call(raw: phone)
    self.phone = normalized if normalized
  end

  def phone_is_valid_mx_number
    return if phone.blank?
    return if Phonelib.valid_for_country?(phone, "MX")
    errors.add(:phone, :invalid)
  end
end
