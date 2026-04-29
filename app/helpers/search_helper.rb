module SearchHelper
  RESULT_ICONS = {
    orders:      :shopping_bag,
    clients:     :user,
    recipes:     :chef_hat,
    ingredients: :scale,
    suppliers:   :store
  }.freeze

  def search_result_icon(kind)
    RESULT_ICONS.fetch(kind, :search)
  end

  def search_result_path(kind, record)
    case kind
    when :orders      then order_path(record)
    when :clients     then client_path(record)
    when :recipes     then recipe_path(record)
    when :ingredients then ingredient_path(record)
    when :suppliers   then supplier_path(record)
    end
  end
end
