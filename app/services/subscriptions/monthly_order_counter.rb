module Subscriptions
  # Counts pedidos in the current calendar month for an account and
  # decides what state the pedidos-cap pill should render in.
  #
  # Phase 14 promised a 40-pedidos/mes Free cap. The counter is the
  # single source of truth — every surface that needs to know "are
  # we close to the limit?" reads through this service rather than
  # duplicating the SQL or the threshold rules.
  #
  # We count `Order` rows by `created_at` (server time) within the
  # current month, scoped to the account. `Cancelados` count too —
  # otherwise an operator could rage-cancel + re-place repeatedly to
  # bypass the cap. `Pro` always returns `unlimited: true`, so the
  # caller can short-circuit before hitting the DB.
  class MonthlyOrderCounter < ApplicationService
    Result = Struct.new(:count, :limit, :state, :unlimited, keyword_init: true) do
      def remaining
        return nil if unlimited
        [ limit - count, 0 ].max
      end

      def percent
        return 0 if unlimited || limit.to_i.zero?
        ((count.to_f / limit) * 100).clamp(0, 100).round
      end

      def reached?
        !unlimited && count >= limit
      end

      def approaching?
        state == :approaching
      end

      def near_limit?
        state == :near_limit
      end

      def safe?
        state == :safe
      end
    end

    # Threshold rules. Soft-warn at 35/40 (87.5%), louder at 38/40
    # (95%), hard-stop at 40/40 (100%). Tuning room: if the operator
    # data shows 35/40 surfaces too late, dial back to 30 (75%).
    APPROACHING_PERCENT = 87
    NEAR_LIMIT_PERCENT  = 95

    option :account
    option :now, default: -> { Time.current }

    def call
      entitlements = Entitlements.for(account)

      if entitlements.unlimited_orders?
        return Result.new(count: count_for_window, limit: nil, state: :unlimited, unlimited: true)
      end

      limit = entitlements.monthly_orders_limit
      count = count_for_window
      Result.new(count: count, limit: limit, state: state_for(count, limit), unlimited: false)
    end

    private

    def count_for_window
      account.orders.where(created_at: month_start..month_end).count
    end

    def month_start
      now.beginning_of_month
    end

    def month_end
      now.end_of_month
    end

    def state_for(count, limit)
      pct = (count.to_f / limit) * 100
      return :reached      if count >= limit
      return :near_limit   if pct >= NEAR_LIMIT_PERCENT
      return :approaching  if pct >= APPROACHING_PERCENT
      :safe
    end
  end
end
