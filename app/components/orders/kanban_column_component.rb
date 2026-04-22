module Orders
  # Vertical kanban column for one Order state. Header (kicker + count
  # pill) + scrollable list of order cards rendered through `_card`. The
  # whole list lives inside a Turbo refresh; whenever an order in the
  # account moves, the page morphs in place.
  class KanbanColumnComponent < ApplicationComponent
    # States with a "whole column at once" motion. Canceled + delivered
    # are terminal — no bulk action. `en_route` could bulk-`deliver` in
    # theory, but in practice runners mark one-by-one from /r/:token, so
    # we skip it until asked.
    BULK_EVENT_FOR_STATE = {
      "placed"        => :confirm,
      "confirmed"     => :start_production,
      "in_production" => :mark_ready,
      "ready"         => :ship
    }.freeze

    option :state
    option :orders

    def column_title = I18n.t("orders.columns.#{state}")
    def count_label  = I18n.t("orders.columns.count", count: orders.size)
    def empty_label  = I18n.t("orders.columns.empty")
    def column_id    = "orders_#{state}"

    def bulk_event
      BULK_EVENT_FOR_STATE[state]
    end

    def bulk_available?
      bulk_event.present? && orders.any?
    end

    def bulk_cta_label
      I18n.t("orders.bulk.#{bulk_event}.cta", count: orders.size)
    end

    def bulk_confirm_copy
      I18n.t("orders.bulk.#{bulk_event}.confirm", count: orders.size)
    end
  end
end
