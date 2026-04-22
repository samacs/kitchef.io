module Production
  # A single card in the 7-day top strip on `/production`. Shows pedido
  # totals and up to three quick-action chips ("3 por confirmar",
  # "5 a cocinar", "2 entregas"). Click navigates to `?on=YYYY-MM-DD` on
  # the same page, expanding that day's drill-down.
  class DayCardComponent < ApplicationComponent
    DAY_LABELS = %w[Dom Lun Mar Mié Jue Vie Sáb].freeze

    option :row                        # Production::WeekOverview::DayRow
    option :active, default: -> { false }
    option :today,  default: -> { false }

    def weekday_label
      DAY_LABELS[row.date.wday]
    end

    def date_label
      row.date.day.to_s.rjust(2, "0")
    end

    def count_label
      I18n.t("production.day_card.count", count: row.total)
    end

    def chips
      @chips ||= [
        chip_for(:to_confirm, row.to_confirm),
        chip_for(:to_cook,    row.to_cook),
        chip_for(:to_deliver, row.to_deliver)
      ].compact
    end

    def empty?
      row.empty?
    end

    private

    def chip_for(key, count)
      return nil if count.zero?

      I18n.t("production.day_card.chips.#{key}", count: count)
    end
  end
end
