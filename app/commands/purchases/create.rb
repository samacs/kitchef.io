module Purchases
  # Creates a Purchase + its PurchaseItem lines, then cascades:
  #
  #   1. For each item, find-or-create a SupplierIngredient row for
  #      `(purchase.supplier_id, item.ingredient_id)`. If the purchase
  #      is "sin proveedor" (nil supplier), skip this step — it informs
  #      gastos but doesn't touch per-supplier price history.
  #   2. Stamp the SupplierIngredient with the new unit cost (normalized
  #      to the ingredient's canonical unit when units differ) and
  #      `last_bought_on = purchased_on`.
  #   3. If the ingredient has no default yet, promote the new row.
  #   4. SupplierIngredient's `after_save` refreshes
  #      `ingredient.unit_cost_cents`, which triggers Phase 7's
  #      `Recipes::DependencyGraph` cascade so every recipe using the
  #      ingredient gets its `cost_cents_cached` refreshed.
  #
  # The whole thing runs in a single transaction — a partial failure
  # must not leave half-updated supplier prices.
  class Create < ApplicationCommand
    option :account
    option :params
    option :receipt_photo, optional: true

    def call
      purchase = account.purchases.new(normalized_params)
      purchase.receipt_photo.attach(receipt_photo) if receipt_photo.present?

      ActiveRecord::Base.transaction do
        purchase.save!
        apply_cascade(purchase) if purchase.supplier.present?
      end

      success(purchase)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, object: e.record, errors: e.record.errors)
    end

    private

    def normalized_params
      attrs = params.to_h.deep_symbolize_keys

      # Accept `total_override` as a decimal-peso string and convert.
      if attrs[:total_override].present?
        attrs[:total_cents_override] = (BigDecimal(attrs.delete(:total_override).to_s.tr(",", "")) * 100).to_i
      end

      # Accept `unit_cost` on each nested item — mirrors the ingredient form.
      if attrs[:items_attributes].is_a?(Hash)
        attrs[:items_attributes] = attrs[:items_attributes].values
      end
      (attrs[:items_attributes] || []).each do |item|
        if item[:unit_cost].present?
          item[:unit_cost_cents] = (BigDecimal(item.delete(:unit_cost).to_s.tr(",", "")) * 100).to_i
        end
        # Default unit: the ingredient's canonical unit (so the form can
        # omit per-line unit on the common path).
        if item[:unit].blank? && item[:ingredient_id].present?
          ing = account.ingredients.kept.find_by(id: item[:ingredient_id])
          item[:unit] = ing&.unit
        end
      end

      attrs
    end

    def apply_cascade(purchase)
      purchase.items.reload.each do |item|
        si = find_or_build_supplier_ingredient(purchase, item)
        si.unit_cost_cents = item.unit_cost_cents_in_ingredient_unit
        si.last_bought_on = purchase.purchased_on
        si.is_default_cost_source = true if promote_to_default?(item)
        si.save!
      end
    end

    def find_or_build_supplier_ingredient(purchase, item)
      SupplierIngredient
        .find_or_initialize_by(supplier_id: purchase.supplier_id, ingredient_id: item.ingredient_id)
    end

    def promote_to_default?(item)
      # Auto-promote when the ingredient currently has no default.
      item.ingredient.supplier_ingredients.default.empty?
    end
  end
end
