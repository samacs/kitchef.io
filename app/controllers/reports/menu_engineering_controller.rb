require "csv"

module Reports
  class MenuEngineeringController < AuthenticatedController
    DEFAULT_PRESET = :last_30_days

    # Bucket sizes — top-N stars, bottom-N review. The "steady" group is
    # everything in between. Kept small on purpose: an operator shouldn't
    # scroll through a flat ranking — the point of the buckets is to say
    # "these are the three you'd tell a friend about, these are the three
    # you'd reconsider, and these are the rest".
    STAR_COUNT = 3
    REVIEW_COUNT = 3

    def show
      @range_preset = resolve_preset
      @starting, @ending = resolved_range

      @rows = ::Reports::RecipePerformance.call(
        account:  Current.account,
        starting: @starting,
        ending:   @ending
      )

      @has_signal = @rows.count { |r| !r.idle? } >= 3

      @stars, @steady, @review = bucket_rows(@rows) if @has_signal

      respond_to do |format|
        format.html
        format.csv { send_data build_csv, filename: csv_filename, type: "text/csv; charset=utf-8" }
      end
    end

    private

    def resolve_preset
      candidate = params[:range].to_s.to_sym
      return candidate if ::Reports::Finance::PRESETS.include?(candidate)
      return :custom if params[:from].present? && params[:to].present?

      DEFAULT_PRESET
    end

    def resolved_range
      if @range_preset == :custom
        from = safe_parse_date(params[:from]) || Date.current - 29
        to   = safe_parse_date(params[:to])   || Date.current
        to = from if to < from
        [ from, to ]
      else
        ::Reports::Finance.resolve_preset(@range_preset)
      end
    end

    def safe_parse_date(raw)
      Date.iso8601(raw.to_s)
    rescue ArgumentError, Date::Error
      nil
    end

    # Split into three buckets:
    #   stars   — top N by margin contribution, excluding idle
    #   steady  — the middle band (everything not star + not review)
    #   review  — idle platillos first, then the bottom-N-by-margin with
    #             at least one sale. Idle platillos always win the
    #             "revisa estos" bucket (a recipe with zero pedidos in
    #             the window is the clearest review signal).
    def bucket_rows(rows)
      sold   = rows.reject(&:idle?).sort_by { |r| -r.margin_cents }
      idle   = rows.select(&:idle?)

      stars = sold.first(STAR_COUNT)

      # Bottom-of-the-pack sold rows (by margin ascending). If idle rows
      # already fill REVIEW_COUNT, the sold tail is dropped so the review
      # bucket stays focused.
      review_slots = [ REVIEW_COUNT - idle.size, 0 ].max
      review_sold  = sold.last(review_slots).reject { |r| stars.include?(r) }
      review       = idle + review_sold

      steady = sold - stars - review

      [ stars, steady, review ]
    end

    def build_csv
      CSV.generate(write_headers: true, force_quotes: true) do |csv|
        csv << [
          t("reports.menu_engineering.csv.headers.recipe"),
          t("reports.menu_engineering.csv.headers.units_sold"),
          t("reports.menu_engineering.csv.headers.revenue"),
          t("reports.menu_engineering.csv.headers.cogs"),
          t("reports.menu_engineering.csv.headers.margin"),
          t("reports.menu_engineering.csv.headers.margin_pct")
        ]

        @rows.sort_by { |r| -r.margin_cents }.each do |row|
          csv << [
            row.recipe.name,
            format_units(row.units_sold),
            cents_to_mxn(row.revenue_cents),
            cents_to_mxn(row.cogs_cents),
            cents_to_mxn(row.margin_cents),
            row.margin_pct
          ]
        end
      end.then { |body| "\uFEFF" + body }
    end

    def cents_to_mxn(cents)
      format("%.2f", cents / 100.0)
    end

    # Idle rows come through as Integer 0; sold rows as BigDecimal. Format
    # both consistently without the trailing ".0" on integer counts.
    def format_units(qty)
      return "0" if qty.nil? || qty.zero?
      formatted = BigDecimal(qty.to_s).to_s("F").sub(/\.0+\z/, "").sub(/(\.\d*?)0+\z/, '\1')
      formatted.presence || qty.to_s
    end

    def csv_filename
      "menu-#{@starting.iso8601}_a_#{@ending.iso8601}.csv"
    end
  end
end
