module Ui
  # Card primitive per DESIGN.md §5.3.
  #
  #   <%= render Ui::CardComponent.new do %>
  #     Card contents…
  #   <% end %>
  #
  #   <%= render Ui::CardComponent.new(variant: :showcase) do %>
  #     Hero / pricing / empty-state…
  #   <% end %>
  class CardComponent < ApplicationComponent
    VARIANTS = %i[default compact showcase].freeze

    option :variant, default: -> { :default }
    option :tag,     default: -> { :article }

    def call
      content_tag(tag, class: classes) { content }
    end

    private

    def classes
      base = %w[bg-surface border border-line shadow-card flex flex-col]
      case variant
      when :compact  then base + %w[rounded-card-sm p-4 gap-3]
      when :showcase then base + %w[rounded-panel p-12 gap-4]
      else               base + %w[rounded-card p-7 gap-[14px]]
      end.join(" ")
    end
  end
end
