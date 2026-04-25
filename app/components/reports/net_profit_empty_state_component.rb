module Reports
  # The "agrega tus costos fijos" nudge that replaces the Utilidad neta
  # card on /reports/finance until at least one FixedCost exists.
  class NetProfitEmptyStateComponent < ApplicationComponent
    def href
      helpers.fixed_costs_path
    end
  end
end
