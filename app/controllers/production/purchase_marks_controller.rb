module Production
  # "Marcar como comprada" — the quickest path from the shopping list
  # to a real Purchase row. Ingredient + qty come pre-filled from the
  # row the operator tapped; supplier + price are the two things she
  # keys in.
  #
  # If a Purchase already exists today for (account, supplier), this
  # appends a new PurchaseItem to it. Otherwise, it creates a fresh
  # Purchase for today.
  class PurchaseMarksController < AuthenticatedController
    before_action :load_ingredient

    def new
      # Suggest the ingredient's current default supplier + price so
      # the form is pre-populated for the common case.
      default_si = @ingredient.default_supplier_ingredient

      @suggested_supplier_id = default_si&.supplier_id
      @suggested_unit_cost   = default_si&.unit_cost_cents.to_i
      @suggested_qty         = params[:qty].presence
      @suggested_unit        = params[:unit].presence || @ingredient.unit
    end

    def create
      qty       = BigDecimal(params.require(:quantity).to_s.tr(",", ""))
      unit      = params.require(:unit)
      cost      = parse_cost_to_cents(params.require(:unit_cost))
      supplier  = resolve_supplier(params[:supplier_id])

      ActiveRecord::Base.transaction do
        purchase = find_or_build_today_purchase(supplier)
        purchase.save! if purchase.new_record?

        item = purchase.items.create!(
          ingredient: @ingredient,
          quantity: qty,
          unit: unit,
          unit_cost_cents: cost
        )

        if supplier.present?
          update_supplier_ingredient(purchase, item)
        end

        purchase.save!   # recomputes total_cents
      end

      flash[:notice] = t("shopping_list.mark_bought_create.marked", name: @ingredient.name)

      respond_to do |format|
        # The form lives inside the drawer's `drawer_content` frame. A
        # plain redirect to /production/shopping-list would make Turbo
        # look for a matching frame in that page and fall back to
        # "Content missing" since the shopping list itself has no
        # drawer_content frame. `close_drawer_and_refresh` empties the
        # frame (drawer slides shut) and morph-refreshes the underlying
        # page so the new ✓ mark + updated totals appear in place.
        format.turbo_stream { render turbo_stream: close_drawer_and_refresh }
        format.html { redirect_to production_shopping_list_path }
      end
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = e.message
      respond_to do |format|
        format.turbo_stream { render turbo_stream: close_drawer_and_refresh }
        format.html { redirect_to production_shopping_list_path }
      end
    end

    private

    def load_ingredient
      @ingredient = Current.account.ingredients.kept.find(params[:ingredient_id])
    end

    def resolve_supplier(raw)
      return nil if raw.blank?
      Current.account.suppliers.kept.find_by(id: raw)
    end

    def find_or_build_today_purchase(supplier)
      # Match on (account, supplier_id, purchased_on = today) — NULL
      # supplier_id matches other "sin proveedor" marks so a lot of
      # one-off grocery captures roll up to a single Purchase.
      scope = Current.account.purchases.kept.where(purchased_on: Date.current)
      scope = supplier.present? ? scope.where(supplier_id: supplier.id) : scope.where(supplier_id: nil)
      scope.first || Current.account.purchases.new(purchased_on: Date.current, supplier: supplier)
    end

    def update_supplier_ingredient(purchase, item)
      si = SupplierIngredient.find_or_initialize_by(
        supplier_id: purchase.supplier_id,
        ingredient_id: item.ingredient_id
      )
      si.unit_cost_cents  = item.unit_cost_cents_in_ingredient_unit
      si.last_bought_on   = purchase.purchased_on
      si.is_default_cost_source = true if item.ingredient.supplier_ingredients.default.empty?
      si.save!
    end

    def parse_cost_to_cents(raw)
      return 0 if raw.blank?
      normalized = raw.to_s.tr(",", "")
      (BigDecimal(normalized) * 100).to_i
    rescue ArgumentError
      0
    end
  end
end
