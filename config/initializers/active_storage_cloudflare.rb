require_relative "../../lib/active_storage/service/cloudflare_r2_service"

# Override Active Storage URL generation so that image_tag, url_for, etc.
# produce direct CDN URLs (e.g. https://media.kitchef.mx/...) instead of
# /rails/active_storage/... proxy/redirect routes.
#
# We can't use route resolve() blocks because engine routes load after
# application routes and override them.
ActiveSupport.on_load(:action_view) do
  module ActiveStoragePublicUrls
    private

    def resolve_asset_source(asset_type, source, skip_pipeline)
      case source
      when ActiveStorage::VariantWithRecord
        return source.processed.url if source.blob.service.public?
      when ActiveStorage::Blob
        return source.url if source.service.public?
      when ActiveStorage::Attachment
        return source.blob.url if source.blob.service.public?
      end

      super
    end
  end

  ActionView::Helpers::AssetTagHelper.prepend(ActiveStoragePublicUrls)
end

ActiveSupport.on_load(:action_view) do
  module ActiveStoragePublicUrlFor
    def url_for(options = nil)
      case options
      when ActiveStorage::VariantWithRecord
        return options.processed.url if options.blob.service.public?
      when ActiveStorage::Blob
        return options.url if options.service.public?
      when ActiveStorage::Attachment
        return options.blob.url if options.blob.service.public?
      end

      super
    end
  end

  ActionView::RoutingUrlFor.prepend(ActiveStoragePublicUrlFor)
end
