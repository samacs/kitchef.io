module Orders
  # Vertical kanban column for one Order state. Header (kicker + count
  # pill) + scrollable list of order cards rendered through `_card`. The
  # whole list lives inside a Turbo refresh; whenever an order in the
  # account moves, the page morphs in place.
  class KanbanColumnComponent < ApplicationComponent
    option :state
    option :orders

    def column_title = I18n.t("orders.columns.#{state}")
    def count_label  = I18n.t("orders.columns.count", count: orders.size)
    def empty_label  = I18n.t("orders.columns.empty")
    def column_id    = "orders_#{state}"
  end
end
