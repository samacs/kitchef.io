module Ui
  # Standard button primitive per DESIGN.md §5.1.
  #
  #   <%= render Ui::ButtonComponent.new(label: "Nuevo pedido") %>
  #   <%= render Ui::ButtonComponent.new(label: "Entra", variant: :primary, size: :lg) %>
  #   <%= render Ui::ButtonComponent.new(label: "Cancelar", variant: :ghost, href: dashboard_path) %>
  class ButtonComponent < ApplicationComponent
    VARIANTS = %i[default primary ghost].freeze
    SIZES    = %i[sm md].freeze

    option :label
    option :variant, default: -> { :default }
    option :size,    default: -> { :md }
    option :href,    optional: true
    option :type,    default: -> { "button" }
    option :icon,    optional: true
    option :data,    default: -> { {} }

    def call
      tag_name = href.present? ? :a : :button
      attrs = {
        class: classes,
        data: data
      }
      attrs[:href] = href if tag_name == :a
      attrs[:type] = type  if tag_name == :button

      content_tag(tag_name, **attrs) do
        [ icon.present? ? helpers.icon(icon, size: :sm) : nil, label ].compact.join.html_safe
      end
    end

    private

    def classes
      base = %w[inline-flex items-center justify-center gap-2 font-semibold
                transition border rounded-button
                focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-bg]
      base << size_classes
      base << variant_classes
      base.flatten.join(" ")
    end

    def size_classes
      case size
      when :sm then %w[px-3 py-[7px] text-[13px]]
      else %w[px-[18px] py-[10px] text-sm]
      end
    end

    def variant_classes
      case variant
      when :primary
        %w[bg-accent hover:bg-accent-2 text-bg border-accent hover:border-accent-2 shadow-cta]
      when :ghost
        %w[bg-transparent border-transparent text-ink hover:border-line]
      else
        %w[bg-surface text-ink border-line hover:border-line-2]
      end
    end
  end
end
