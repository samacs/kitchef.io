module Storefronts
  # Public-facing, unauthenticated storefront surface. The slug comes from
  # the root-level path constraint in config/routes.rb, which already
  # rejects Account::RESERVED_SLUGS — by the time we resolve here the slug
  # is guaranteed not to collide with an app route.
  class BaseController < ApplicationController
    allow_unauthenticated_access

    layout "storefront"

    before_action :set_storefront
    rescue_from ActiveRecord::RecordNotFound, with: :storefront_not_found

    private

    def set_storefront
      @storefront = Account.friendly.kept.find(params[:slug])
    end

    def storefront_not_found
      render "storefronts/not_found", status: :not_found
    end
  end
end
