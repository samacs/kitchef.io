module Marketing
  # Detailed Free vs Pro feature comparison table on /pricing.
  # Source rows live in `marketing.feature_comparison.rows` so copy
  # tweaks don't ship via deploy.
  #
  # Each row in the locale yields:
  #   { label: "Pedidos al mes",
  #     free: "Hasta 40",         # string OR `true` (✓) / `false` (—)
  #     pro: "Ilimitados" }
  #
  # The component renders strings as-is and booleans as a green check
  # / muted dash. Section dividers use `{ section: "Crecer tu cocina" }`
  # rows.
  class FeatureComparisonComponent < ApplicationComponent
    def rows
      @rows ||= I18n.t("marketing.feature_comparison.rows", default: []).to_a
    end

    def section_row?(row)
      row[:section].present?
    end

    def render_cell(value)
      case value
      when true
        helpers.tag.span(check_icon, class: "inline-flex text-accent")
      when false, nil
        helpers.tag.span("—", class: "text-muted")
      else
        helpers.tag.span(value, class: "text-ink-2")
      end
    end

    private

    def check_icon
      helpers.icon(:check, size: :sm)
    end
  end
end
