module Promotions
  class CardComponent < ApplicationComponent
    option :promotion

    delegate :name, :code, :kind, :discount_type, :scope_type,
             :discount_value, :active?, :expired?,
             :bogo_buy_quantity, :bogo_get_quantity,
             :total_usage_count, :total_usage_limit,
             to: :promotion

    def status_label
      return I18n.t("promotions.card.expired") if expired?
      active? ? I18n.t("promotions.card.active") : I18n.t("promotions.card.inactive")
    end

    def status_classes
      if expired?
        "bg-[color-mix(in_oklab,var(--color-warn)_12%,var(--color-surface))] text-warn border-warn/30"
      elsif active?
        "bg-accent-soft text-accent border-accent/30"
      else
        "bg-bg-2 text-muted border-line"
      end
    end

    def discount_display
      case discount_type
      when "percentage"
        "#{discount_value}%"
      when "fixed_amount"
        helpers.humanized_money_with_symbol(Money.new(discount_value, "MXN"))
      when "bogo"
        I18n.t("promotions.card.bogo_label",
               buy: bogo_buy_quantity, get: bogo_get_quantity)
      end
    end

    def scope_detail
      case scope_type
      when "recipe"
        names = promotion.recipes.limit(3).pluck(:name).join(", ")
        extra = promotion.recipes.count - 3
        names += " +#{extra}" if extra.positive?
        I18n.t("promotions.card.scope_recipes", names: names)
      when "category"
        names = promotion.categories.limit(3).pluck(:name).join(", ")
        I18n.t("promotions.card.scope_categories", names: names)
      end
    end

    def usage_display
      if total_usage_limit
        I18n.t("promotions.card.usage_limit",
               used: total_usage_count, limit: total_usage_limit)
      else
        I18n.t("promotions.card.unlimited")
      end
    end

    def expiry_display
      if promotion.ends_at.present?
        I18n.t("promotions.card.ends",
               date: I18n.l(promotion.ends_at.to_date, format: :long))
      else
        I18n.t("promotions.card.no_expiry")
      end
    end

    def toggle_label
      active? ? I18n.t("promotions.card.toggle_deactivate") : I18n.t("promotions.card.toggle_activate")
    end
  end
end
