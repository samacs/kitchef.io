module Recipes
  # Small inline chip next to the sale-price input that grades the recipe's
  # current margin: green when above target, warn when below, err when the
  # recipe actually loses money. Hidden for internal recipes (no sale
  # price) and for recipes without a computed cost (`cost_cents_cached:
  # nil`).
  class MarginChipComponent < ApplicationComponent
    option :recipe

    def render?
      recipe.is_saleable? &&
        recipe.sale_price_cents.to_i.positive? &&
        recipe.cost_cents_cached.present?
    end

    def call
      content_tag(:span, class: classes, title: tooltip) do
        [ label ].compact.join(" ").strip.html_safe
      end
    end

    private

    def margin_pct
      @margin_pct ||= begin
        return nil if recipe.sale_price_cents.to_i <= 0 || recipe.cost_cents_cached.nil?

        (((recipe.sale_price_cents - recipe.cost_cents_cached).to_f / recipe.sale_price_cents) * 100).round
      end
    end

    def target
      recipe.target_margin_percent.to_i
    end

    def status
      return :err  if margin_pct.to_i.negative?
      return :warn if margin_pct.to_i < target
      :ok
    end

    def label
      return I18n.t("recipes.margin_chip.loss") if status == :err

      I18n.t("recipes.margin_chip.label", pct: margin_pct)
    end

    def tooltip
      I18n.t("recipes.margin_chip.tooltip", target: target)
    end

    def classes
      base = "inline-flex items-center gap-1 rounded-pill px-2.5 py-[3px] text-[11px] font-mono font-medium leading-none"
      case status
      when :ok
        "#{base} bg-accent-soft text-accent border border-transparent"
      when :warn
        "#{base} bg-[color-mix(in_oklab,var(--color-warn,#B04E0E)_10%,var(--color-surface))] text-[var(--color-warn,#B04E0E)] border border-[color-mix(in_oklab,var(--color-warn,#B04E0E)_40%,transparent)]"
      else
        "#{base} bg-[color-mix(in_oklab,var(--color-err)_10%,var(--color-surface))] text-err border border-err/30"
      end
    end
  end
end
