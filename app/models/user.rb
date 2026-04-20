# == Schema Information
#
# Table name: users
#
#  id               :bigint           not null, primary key
#  admin            :boolean          default(FALSE), not null
#  discarded_at     :datetime
#  email_address    :string           not null
#  first_name       :string
#  last_name        :string
#  password_digest  :string           not null
#  phone            :string
#  phone_normalized :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint
#
# Indexes
#
#  index_users_on_account_id     (account_id)
#  index_users_on_admin          (admin) WHERE (admin = true)
#  index_users_on_discarded_at   (discarded_at)
#  index_users_on_email_address  (email_address) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class User < ApplicationRecord
  include HasSoftDelete

  has_secure_password
  has_person_name
  phony_normalize :phone, as: :phone_normalized, default_country_code: "MX"

  belongs_to :account, optional: true
  has_many   :sessions, dependent: :destroy
  has_one    :owned_account, class_name: "Account", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :first_name, presence: true
  validates :last_name,  presence: true
  validate  :phone_is_valid_mx_number

  private

  def phone_is_valid_mx_number
    return if phone.blank?
    return if Phonelib.valid_for_country?(phone, "MX")

    errors.add(:phone, :invalid)
  end
end
