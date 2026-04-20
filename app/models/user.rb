# == Schema Information
#
# Table name: users
#
#  id                :bigint           not null, primary key
#  admin             :boolean          default(FALSE), not null
#  discarded_at      :datetime
#  email_address     :string           not null
#  first_name        :string
#  last_name         :string
#  password_digest   :string           not null
#  phone             :string
#  phone_normalized  :string
#  terms_accepted_at :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint
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

  attr_accessor :terms_accepted

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :first_name, presence: true
  validates :last_name,  presence: true
  validate  :phone_is_valid_mx_number
  validate  :terms_must_be_accepted, on: :create

  def terms_accepted?
    terms_accepted_at.present?
  end

  private

  def phone_is_valid_mx_number
    return if phone.blank?
    return if Phonelib.valid_for_country?(phone, "MX")

    errors.add(:phone, :invalid)
  end

  # The sign-up form posts `terms_accepted` as "1"; Registrations::CreateUser
  # stamps `terms_accepted_at` before save. Either being set satisfies the
  # check — programmatic creations (seeds, fixtures, back-office scripts)
  # that set `terms_accepted_at` directly don't need to flip the flag.
  def terms_must_be_accepted
    return if terms_accepted_at.present?
    return if ActiveModel::Type::Boolean.new.cast(terms_accepted)

    errors.add(:terms_accepted, :required)
  end
end
