module Storefronts
  # Legacy redirect. The storefront root now carries the full menu, so a
  # customer who lands on a shared `/:slug/menu` link from an older share
  # still gets the goods without a dead page. Kept as 301 because the
  # URL move is intentional and permanent.
  class MenusController < BaseController
    def show
      redirect_to storefront_path(slug: @storefront.slug), status: :moved_permanently
    end
  end
end
