module Purchases
  # Single row in the /compras index. Renders the compact receipt
  # summary: date · supplier · item count · total · photo badge.
  class IndexRowComponent < ApplicationComponent
    option :purchase

    def show_path
      helpers.purchase_path(purchase)
    end

    def supplier_label
      purchase.supplier_name || helpers.t("purchases.no_supplier")
    end

    def total_label
      helpers.humanized_money_with_symbol(purchase.total)
    end

    def items_label
      helpers.t("purchases.show.item_count", count: purchase.item_count)
    end

    def date_label
      helpers.l(purchase.purchased_on, format: :long)
    end

    def receipt_attached?
      purchase.receipt_photo?
    end
  end
end
