module Storefronts
  class OrdersController < BaseController
    def new
      render_stub(title: t("storefronts.orders.new_title"), meta: "storefronts/orders#new — #{@storefront.slug}")
    end

    def create
      render_stub(title: t("storefronts.orders.created_title"), meta: "storefronts/orders#create — #{@storefront.slug}")
    end

    def show
      render_stub(title: t("storefronts.orders.show_title"), meta: "storefronts/orders#show — #{@storefront.slug}/#{params[:id]}")
    end
  end
end
