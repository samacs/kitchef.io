module Ui
  # Circular avatar — initial on an accent gradient fallback, or an image.
  # Matches the sidebar identity card in the dashboard prototype:
  # linear-gradient(135deg, accent, accent-2) + serif italic initial.
  #
  #   <%= render Ui::AvatarComponent.new(name: current_user.name, size: :md) %>
  #   <%= render Ui::AvatarComponent.new(name: "Elena", image_url: "...", size: :lg) %>
  class AvatarComponent < ApplicationComponent
    SIZES = %i[xs sm md lg xl].freeze

    option :name
    option :image_url, optional: true
    option :size,      default: -> { :md }
    option :ring,      default: -> { false }

    def call
      content_tag(:span, class: wrapper_classes, role: "img", aria: { label: name }) do
        if image_url.present?
          image_tag(image_url, alt: "", class: "w-full h-full object-cover")
        else
          content_tag(:span, initial, class: "font-serif italic leading-none")
        end
      end
    end

    private

    def wrapper_classes
      [
        "inline-flex items-center justify-center shrink-0 overflow-hidden",
        "rounded-pill text-bg",
        dimension,
        ("bg-[linear-gradient(135deg,var(--color-accent),var(--color-accent-2))]" if image_url.blank?),
        ("ring-2 ring-surface" if ring)
      ].compact.join(" ")
    end

    def dimension
      case size
      when :xs then "w-[22px] h-[22px] text-[12px]"
      when :sm then "w-[28px] h-[28px] text-[14px]"
      when :lg then "w-[40px] h-[40px] text-[19px]"
      when :xl then "w-[56px] h-[56px] text-[26px]"
      else          "w-[34px] h-[34px] text-[17px]"
      end
    end

    def initial
      return "" if name.blank?
      name.to_s.strip[0].to_s.upcase
    end
  end
end
