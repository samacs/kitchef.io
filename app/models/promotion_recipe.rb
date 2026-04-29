# == Schema Information
#
# Table name: promotion_recipes
#
#  id           :bigint           not null, primary key
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  promotion_id :bigint           not null
#  recipe_id    :bigint           not null
#
# Indexes
#
#  index_promotion_recipes_on_promotion_id  (promotion_id)
#  index_promotion_recipes_on_recipe_id     (recipe_id)
#  uniq_promotion_recipes                   (promotion_id,recipe_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (promotion_id => promotions.id) ON DELETE => cascade
#  fk_rails_...  (recipe_id => recipes.id) ON DELETE => cascade
#
class PromotionRecipe < ApplicationRecord
  belongs_to :promotion
  belongs_to :recipe
end
