module MetaHelper
  def page_title(base_title = "Kitchef", reverse: true, glue: " | ")
    parts = [ base_title, content_for(:title) ].compact
    parts.reverse! if reverse
    tag.title(parts.join(glue))
  end

  def meta_description(default = nil)
    content = content_for(:meta_description).presence ||
              content_for(:description).presence ||
              default ||
              t("meta.default_description")
    tag.meta(name: "description", content: content.truncate(160))
  end

  def meta_robots(content = nil)
    robots = content || content_for(:meta_robots).presence || "index, follow"
    tag.meta(name: "robots", content: robots)
  end

  def canonical_url(url = nil)
    canonical = url || content_for(:canonical_url).presence || request.original_url.split("?").first
    tag.link(rel: "canonical", href: canonical)
  end

  def standard_meta_tags(
    title: nil,
    description: nil,
    image: nil,
    type: "website",
    url: nil
  )
    safe_join([
      meta_description(description),
      meta_robots,
      canonical_url(url),
      open_graph_tags(title:, description:, image:, type:, url:),
      twitter_tags(title:, description:, image:, url:)
    ].compact)
  end
end
