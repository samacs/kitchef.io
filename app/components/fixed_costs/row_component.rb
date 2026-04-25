module FixedCosts
  # Single row in the /costos-fijos index. Mirrors Suppliers::RowComponent.
  class RowComponent < ApplicationComponent
    option :fixed_cost

    def edit_path
      helpers.edit_fixed_cost_path(fixed_cost)
    end

    def amount
      Money.new(fixed_cost.amount_cents, "MXN")
    end

    def category_name
      fixed_cost.fixed_cost_category&.name
    end

    def recurrence_label
      if fixed_cost.per_pedido?
        I18n.t("fixed_costs.recurrence.per_pedido")
      else
        I18n.t("fixed_costs.recurrence.#{fixed_cost.recurrence}")
      end
    end

    def period_label
      return I18n.t("fixed_costs.period.open", start: helpers.l(fixed_cost.start_date, format: :long)) if fixed_cost.end_date.blank?
      I18n.t("fixed_costs.period.closed",
             start: helpers.l(fixed_cost.start_date, format: :long),
             ending: helpers.l(fixed_cost.end_date, format: :long))
    end

    def per_pedido_amount
      return nil unless fixed_cost.per_pedido?
      Money.new(fixed_cost.cost_per_pedido_cents.to_i, "MXN")
    end
  end
end
