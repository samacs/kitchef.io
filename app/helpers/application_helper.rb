module ApplicationHelper
  def cdn_image_url(source)
    case source
    when ActiveStorage::VariantWithRecord
      source.processed.url
    when ActiveStorage::Variant
      source.processed.url
    when ActiveStorage::Blob
      source.url
    when ActiveStorage::Attachment
      source.blob.url
    else
      url_for(source)
    end
  end
end
