module Production
  class ShoppingListsController < AuthenticatedController
    def show
      render_stub(title: t("production.shopping_list.title"), meta: "production/shopping_lists#show")
    end
  end
end
