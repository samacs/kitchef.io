module Reports
  # Inline SVG column chart for the last N weeks. We bypass chartkick /
  # Chart.js here deliberately — an 8-bar chart is a handful of SVG rects,
  # ships zero KB of JS, renders identically on a 4G phone as on a laptop,
  # and avoids the Stimulus dance of hydrating a canvas element after
  # Turbo navigation. If we ever need drill-down or tooltips we can swap
  # this for chartkick without changing the data shape.
  class TrendChartComponent < ApplicationComponent
    Week = Data.define(:starting, :revenue_cents, :cogs_cents, :order_count) do
      def margin_cents = revenue_cents - cogs_cents
      def margin_pct
        return nil if revenue_cents.zero?
        (margin_cents.to_f / revenue_cents * 100).round
      end
    end

    option :weeks

    # SVG canvas — 680×160 is a comfortable 16:9-ish area at ~340px on a
    # phone (it scales down via CSS). 40px of padding on the left lets
    # bars start clear of the y-axis label area without computing it.
    WIDTH = 680
    HEIGHT = 140
    PAD_TOP = 10
    PAD_BOTTOM = 30
    PAD_LEFT = 8
    PAD_RIGHT = 8

    def inner_width
      WIDTH - PAD_LEFT - PAD_RIGHT
    end

    def inner_height
      HEIGHT - PAD_TOP - PAD_BOTTOM
    end

    def max_revenue
      [ weeks.map(&:revenue_cents).max || 0, 1 ].max
    end

    def bar_slot
      return 0 if weeks.empty?
      inner_width.to_f / weeks.length
    end

    def bar_for(index)
      week = weeks[index]
      slot = bar_slot
      bar_w = [ slot - 8, 12 ].max
      x = PAD_LEFT + (slot * index) + (slot - bar_w) / 2
      h = week.revenue_cents.zero? ? 0 : (week.revenue_cents.to_f / max_revenue * inner_height).round(2)
      y = PAD_TOP + inner_height - h
      { x: x.round(2), y: y.round(2), width: bar_w.round(2), height: h }
    end

    def label_x(index)
      slot = bar_slot
      PAD_LEFT + (slot * index) + slot / 2
    end

    def week_label(week)
      # "14-abr" — short and compact so 8 labels fit on a phone. Month
      # initialism keeps us safely under ~4 chars per label.
      I18n.l(week.starting, format: :short_day_compact)
    end
  end
end
