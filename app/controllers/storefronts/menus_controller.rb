module Storefronts
  class MenusController < BaseController
    def show
      render_stub(title: t("storefronts.menu.title", kitchen: @storefront.name),
        meta: "storefronts/menus#show — #{@storefront.slug}")
    end
  end
end
