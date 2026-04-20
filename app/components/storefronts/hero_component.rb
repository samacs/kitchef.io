module Storefronts
  # Storefront hero — cover image, logo badge, kitchen name (Instrument
  # Serif italic pivot for the differentiator word), tagline, ordering-
  # hours chip, and primary WhatsApp CTA.
  #
  # Mirrors the layout from `tmp/kitchef-design/project/Kitchef Storefront.html`
  # (StoreHeader block) adapted to Kitchef's Tailwind-token chrome.
  class HeroComponent < ApplicationComponent
    option :storefront
    option :ordering_hours  # Storefronts::OrderingHours::Result

    delegate :name, :public_profile, to: :storefront
    delegate :description, :tagline, :colonia, :city, :phone, :whatsapp, :instagram, to: :public_profile

    def cover_image
      storefront.cover_photo if storefront.cover_photo.attached?
    end

    def logo_image
      storefront.logo if storefront.logo.attached?
    end

    def whatsapp_url
      number = whatsapp.presence || phone
      return nil if number.blank?
      normalized = Phone::NormalizeMx.call(raw: number)
      return nil if normalized.blank?
      digits = normalized.sub(/\A\+/, "")
      "https://wa.me/#{digits}"
    end

    def instagram_url
      handle = instagram.to_s.strip.sub(/\A@/, "")
      return nil if handle.blank?
      "https://instagram.com/#{handle}"
    end

    def location_line
      [ colonia, city ].compact_blank.join(" · ").presence
    end
  end
end
