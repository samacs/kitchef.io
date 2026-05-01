module ApplicationHelper
  def format_quantity(value)
    format("%.3f", value.to_d).sub(/\.?0+$/, "")
  end

  def cdn_image_url(source)
    case source
    when ActiveStorage::VariantWithRecord, ActiveStorage::Variant
      rails_representation_url(source.processed)
    when ActiveStorage::Blob
      rails_blob_url(source)
    when ActiveStorage::Attachment
      rails_blob_url(source.blob)
    else
      url_for(source)
    end
  end
end
