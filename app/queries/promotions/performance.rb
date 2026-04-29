module Promotions
  class Performance < ApplicationQuery
    PerformanceRow = Data.define(
      :promotion_id, :name, :kind, :discount_type,
      :redemption_count, :total_discount_cents, :unique_clients
    ) do
      def avg_discount_cents
        return 0 if redemption_count.zero?
        (total_discount_cents.to_f / redemption_count).round
      end
    end

    Summary = Data.define(:total_redemptions, :total_discount_cents, :rows)

    option :account
    option :starting, default: -> { nil }
    option :ending, default: -> { nil }

    def call
      rows = fetch_rows
      Summary.new(
        total_redemptions:  rows.sum(&:redemption_count),
        total_discount_cents: rows.sum(&:total_discount_cents),
        rows: rows
      )
    end

    private

    def fetch_rows
      scope = PromotionRedemption
        .joins(:promotion)
        .where(promotions: { account_id: account.id })

      if starting.present? && ending.present?
        scope = scope.where(promotion_redemptions: { created_at: starting.beginning_of_day..ending.end_of_day })
      end

      scope
        .group("promotions.id, promotions.name, promotions.kind, promotions.discount_type")
        .select(
          "promotions.id AS promotion_id",
          "promotions.name AS name",
          "promotions.kind AS kind",
          "promotions.discount_type AS discount_type",
          "COUNT(*)::integer AS redemption_count",
          "COALESCE(SUM(promotion_redemptions.discount_cents), 0)::bigint AS total_discount_cents",
          "COUNT(DISTINCT promotion_redemptions.client_id)::integer AS unique_clients"
        )
        .order("total_discount_cents DESC")
        .map do |row|
          PerformanceRow.new(
            promotion_id:        row.promotion_id,
            name:                row.name,
            kind:                row.kind,
            discount_type:       row.discount_type,
            redemption_count:    row.redemption_count,
            total_discount_cents: row.total_discount_cents,
            unique_clients:      row.unique_clients
          )
        end
    end
  end
end
