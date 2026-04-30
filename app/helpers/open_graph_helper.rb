module OpenGraphHelper
  def og_title(title = nil)
    content = title || content_for(:title) || "Kitchef"
    content = "#{content} | Kitchef" unless content.include?("Kitchef")
    tag.meta(property: "og:title", content: content)
  end

  def og_description(default = nil)
    description = content_for(:og_description).presence ||
                  content_for(:description).presence ||
                  default ||
                  t("meta.default_description")
    tag.meta(property: "og:description", content: description.truncate(200))
  end

  def og_image(default = nil)
    image = content_for(:og_image).presence || default
    return if image.blank?

    image_url = image.start_with?("http") ? image : "#{request.base_url}#{image}"
    safe_join([
      tag.meta(property: "og:image", content: image_url),
      tag.meta(property: "og:image:width", content: "1200"),
      tag.meta(property: "og:image:height", content: "630")
    ])
  end

  def og_type(default = "website")
    type = content_for(:og_type).presence || default
    tag.meta(property: "og:type", content: type)
  end

  def og_url(default = nil)
    url = content_for(:og_url).presence ||
          content_for(:canonical_url).presence ||
          default ||
          request.original_url.split("?").first
    tag.meta(property: "og:url", content: url)
  end

  def og_site_name
    tag.meta(property: "og:site_name", content: "Kitchef")
  end

  def og_locale
    tag.meta(property: "og:locale", content: "es_MX")
  end

  def open_graph_tags(title: nil, description: nil, image: nil, type: "website", url: nil)
    image ||= image_url("hero.png") if controller_path.start_with?("static_pages")

    safe_join([
      og_title(title),
      og_description(description),
      og_image(image),
      og_type(type),
      og_url(url),
      og_site_name,
      og_locale
    ].compact)
  end
end
