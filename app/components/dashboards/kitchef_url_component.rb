module Dashboards
  class KitchefUrlComponent < ApplicationComponent
    option :account

    def storefront_url
      helpers.storefront_url(slug: account.slug)
    end

    def display_url
      uri = URI.parse(storefront_url)
      path = uri.path.delete_prefix("/")
      if uri.port && ![ 80, 443 ].include?(uri.port)
        "#{uri.host}:#{uri.port}/#{path}"
      else
        "#{uri.host}/#{path}"
      end
    end
  end
end
