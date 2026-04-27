module Storefronts
  # Multi-image carousel for the storefront menu card + dish detail
  # hero. When the recipe has 0–1 photos, renders nothing (the
  # caller should fall back to the legacy single-`<img>` path so
  # card heights stay identical across the grid). When the recipe
  # has 2+ photos, renders a height-stable scroll-snap track + dot
  # indicators + hover-revealed prev/next arrows.
  #
  # Variant decides which Active Storage variant the slides use:
  #   :card → 600×450 — used by the menu grid, lazy-loaded
  #   :hero → 1600×1200 — used by the dish detail page
  class PhotoCarouselComponent < ApplicationComponent
    option :recipe
    option :variant,     default: -> { :card }
    option :alt,         default: -> { nil }
    option :with_thumbs, default: -> { false }

    def render?
      photos.size >= 2
    end

    def photos
      @photos ||= recipe.ordered_photos.to_a
    end

    def alt_text
      alt || recipe.name
    end
  end
end
