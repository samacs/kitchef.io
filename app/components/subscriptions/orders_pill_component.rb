module Subscriptions
  # Pedidos-this-month pill rendered on the /orders topbar for Free
  # operators. Shows "32 / 40 · 8 restantes" with a slim progress
  # bar. Color-codes by threshold (safe / approaching / near-limit /
  # reached). Renders nothing for Pro accounts (unlimited orders).
  #
  # Uses `Subscriptions::MonthlyOrderCounter` as the single source
  # of truth so the pill, the soft-warn HintBanner, and the hard
  # block on `Storefronts::PlaceOrder` all agree on the count.
  class OrdersPillComponent < ApplicationComponent
    option :account

    def render?
      counter.unlimited == false
    end

    def counter
      @counter ||= Subscriptions::MonthlyOrderCounter.call(account: account)
    end

    def progress_class
      case counter.state
      when :reached     then "bg-err"
      when :near_limit  then "bg-warn"
      when :approaching then "bg-warn"
      else                   "bg-accent"
      end
    end

    def container_classes
      base = "inline-flex items-center gap-3 rounded-pill border bg-surface pl-4 pr-2 py-1.5"
      tone = case counter.state
      when :reached     then " border-err/30"
      when :near_limit  then " border-warn/40"
      when :approaching then " border-warn/30"
      else                   " border-line"
      end
      base + tone
    end

    def label
      I18n.t(
        "subscriptions.orders_pill.#{counter.state}",
        count: counter.count,
        limit: counter.limit,
        remaining: counter.remaining
      )
    end

    def cta_path
      helpers.subscription_path(highlight: :unlimited_orders)
    end

    def cta_label
      I18n.t("subscriptions.orders_pill.cta_#{counter.state}", default: I18n.t("subscriptions.orders_pill.cta_default"))
    end

    def cta_visible?
      counter.state.in?(%i[approaching near_limit reached])
    end
  end
end
