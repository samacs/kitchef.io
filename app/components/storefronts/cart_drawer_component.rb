module Storefronts
  # Slide-out cart drawer. All state is client-side (sessionStorage keyed
  # by storefront slug); the drawer's job is to render an empty shell that
  # `storefront_cart_controller.js` fills in on `openDrawer`, and to
  # provide the "Hacer pedido" CTA that serializes the cart into the
  # checkout form.
  class CartDrawerComponent < ApplicationComponent
    option :storefront

    def checkout_href
      helpers.new_storefront_order_path(slug: storefront.slug)
    end
  end
end
