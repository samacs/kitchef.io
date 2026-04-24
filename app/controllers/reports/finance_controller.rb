require "csv"

module Reports
  class FinanceController < AuthenticatedController
    TREND_WEEKS = 8

    def show
      @range_preset = resolve_preset
      @starting, @ending = resolved_range
      @only_paid = ActiveModel::Type::Boolean.new.cast(params[:only_paid])

      @stats = ::Reports::Finance.call(
        account:   Current.account,
        starting:  @starting,
        ending:    @ending,
        only_paid: @only_paid
      )

      @compare_stats = comparison_stats_for(@range_preset)
      @month_to_date = month_to_date_stats

      @trend_weeks = build_trend_weeks if @stats.has_signal?

      respond_to do |format|
        format.html
        format.csv { send_data build_csv, filename: csv_filename, type: "text/csv; charset=utf-8" }
      end
    end

    private

    def resolve_preset
      candidate = params[:range].to_s.to_sym
      return candidate if ::Reports::Finance::PRESETS.include?(candidate)

      # `?from=&to=` → custom, no preset highlighted.
      return :custom if params[:from].present? && params[:to].present?

      :this_week
    end

    def resolved_range
      if @range_preset == :custom
        from = safe_parse_date(params[:from]) || Date.current.beginning_of_week(:monday)
        to   = safe_parse_date(params[:to])   || Date.current
        # Clamp so the custom range never inverts.
        to = from if to < from
        [ from, to ]
      else
        ::Reports::Finance.resolve_preset(@range_preset)
      end
    end

    def safe_parse_date(raw)
      return nil if raw.blank?
      Date.iso8601(raw.to_s)
    rescue ArgumentError, Date::Error
      nil
    end

    # Week-over-week (or period-over-period) comparison. For `this_week` we
    # line up against `last_week`; for `this_month` against `last_month`;
    # for `last_30_days` against the 30 days preceding. Custom + last-week
    # / last-month intentionally skip the compare (their answer is already
    # "the previous period").
    def comparison_stats_for(preset)
      prev_range =
        case preset
        when :this_week  then [ (@starting - 7.days), (@ending - 7.days) ]
        when :this_month then last_month_range
        when :last_30_days
          span = (@ending - @starting).to_i + 1
          [ @starting - span.days, @starting - 1.day ]
        end
      return nil unless prev_range

      ::Reports::Finance.call(
        account:   Current.account,
        starting:  prev_range.first,
        ending:    prev_range.last,
        only_paid: @only_paid
      )
    end

    def last_month_range
      start = (@starting - 1.month).beginning_of_month
      [ start, start.end_of_month ]
    end

    def month_to_date_stats
      today = Date.current
      ::Reports::Finance.call(
        account:   Current.account,
        starting:  today.beginning_of_month,
        ending:    today,
        only_paid: @only_paid
      )
    end

    # Eight-bar trend. The ending anchor is the end of the chosen window
    # rounded out to its containing week — so "this week" still lines up
    # with the last bar on the right. Always runs in ~8 calls of the
    # already-fast aggregator; no N+1 since each call is one GROUP BY.
    def build_trend_weeks
      anchor = @ending.end_of_week(:monday)
      (0...TREND_WEEKS).map do |i|
        week_start = anchor - ((TREND_WEEKS - 1 - i) * 7).days
        week_start = week_start.beginning_of_week(:monday)
        week_end   = week_start + 6.days
        stats = ::Reports::Finance.call(
          account:   Current.account,
          starting:  week_start,
          ending:    week_end,
          only_paid: @only_paid
        )
        ::Reports::TrendChartComponent::Week.new(
          starting:      week_start,
          revenue_cents: stats.revenue_cents,
          cogs_cents:    stats.cogs_cents,
          order_count:   stats.order_count
        )
      end
    end

    # --- CSV -----------------------------------------------------------

    def build_csv
      CSV.generate(write_headers: true, force_quotes: true) do |csv|
        csv << [
          t("reports.finance.csv.headers.date"),
          t("reports.finance.csv.headers.revenue"),
          t("reports.finance.csv.headers.cogs"),
          t("reports.finance.csv.headers.margin"),
          t("reports.finance.csv.headers.margin_pct"),
          t("reports.finance.csv.headers.order_count")
        ]
        @stats.by_day.each do |day|
          csv << [
            day.date.iso8601,
            cents_to_mxn(day.revenue_cents),
            cents_to_mxn(day.cogs_cents),
            cents_to_mxn(day.margin_cents),
            day.margin_pct,
            day.order_count
          ]
        end
      end.then { |body| "\uFEFF" + body }  # BOM so Excel on es-MX opens cleanly
    end

    def cents_to_mxn(cents)
      format("%.2f", cents / 100.0)
    end

    def csv_filename
      "finanzas-#{@starting.iso8601}_a_#{@ending.iso8601}.csv"
    end
  end
end
