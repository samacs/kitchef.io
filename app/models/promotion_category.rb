# == Schema Information
#
# Table name: promotion_categories
#
#  id           :bigint           not null, primary key
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  category_id  :bigint           not null
#  promotion_id :bigint           not null
#
# Indexes
#
#  index_promotion_categories_on_category_id   (category_id)
#  index_promotion_categories_on_promotion_id  (promotion_id)
#  uniq_promotion_categories                   (promotion_id,category_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id) ON DELETE => cascade
#  fk_rails_...  (promotion_id => promotions.id) ON DELETE => cascade
#
class PromotionCategory < ApplicationRecord
  belongs_to :promotion
  belongs_to :category
end
