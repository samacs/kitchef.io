module TwitterHelper
  def twitter_card(type = "summary_large_image")
    tag.meta(name: "twitter:card", content: type)
  end

  def twitter_title(default = nil)
    title = content_for(:twitter_title).presence ||
            content_for(:title).presence ||
            default ||
            "Kitchef"
    title = "#{title} | Kitchef" unless title.include?("Kitchef")
    tag.meta(name: "twitter:title", content: title)
  end

  def twitter_description(default = nil)
    description = content_for(:twitter_description).presence ||
                  content_for(:og_description).presence ||
                  content_for(:description).presence ||
                  default ||
                  t("meta.default_description")
    tag.meta(name: "twitter:description", content: description.truncate(200))
  end

  def twitter_image(default = nil)
    image = content_for(:twitter_image).presence ||
            content_for(:og_image).presence ||
            default
    return if image.blank?

    image_url = image.start_with?("http") ? image : "#{request.base_url}#{image}"
    tag.meta(name: "twitter:image", content: image_url)
  end

  def twitter_tags(title: nil, description: nil, image: nil, url: nil, type: "summary_large_image")
    image ||= image_url("hero.png") if controller_path.start_with?("static_pages")

    safe_join([
      twitter_card(type),
      twitter_title(title),
      twitter_description(description),
      twitter_image(image)
    ].compact)
  end
end
