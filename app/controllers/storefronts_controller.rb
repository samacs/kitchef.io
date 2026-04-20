class StorefrontsController < Storefronts::BaseController
  def show
    render_stub(title: @storefront.name, meta: "storefront — #{@storefront.slug}")
  end
end
