module Ingredients
  # CRUD for an ingredient's per-supplier price rows. Lives inside the
  # ingredient edit drawer at `/ingredients/:ingredient_id/supplier_prices`.
  #
  # Every response re-renders the whole "Proveedores y precios" panel
  # via Turbo Stream so the table, nudge card, and cached ingredient
  # price stay in sync without a full-page reload.
  class SupplierPricesController < AuthenticatedController
    before_action :load_ingredient

    def create
      supplier = Current.account.suppliers.kept.find(params[:supplier_id])

      row = @ingredient.supplier_ingredients.find_or_initialize_by(supplier: supplier)
      row.unit_cost_cents = parse_cost_to_cents(params[:unit_cost])
      row.last_bought_on  = Date.current
      # Auto-promote when this is the ingredient's first supplier.
      if @ingredient.supplier_ingredients.default.empty? && !row.is_default_cost_source?
        row.is_default_cost_source = true
      end

      if row.save
        render_panel
      else
        render_panel(status: :unprocessable_content, error: row.errors.full_messages.to_sentence)
      end
    end

    def update
      row = @ingredient.supplier_ingredients.find(params[:id])

      if params[:make_default] == "1"
        row.promote_to_default!
        return render_panel
      end

      if row.update(row_params)
        render_panel
      else
        render_panel(status: :unprocessable_content, error: row.errors.full_messages.to_sentence)
      end
    end

    def destroy
      row = @ingredient.supplier_ingredients.find(params[:id])
      row.destroy!

      # Auto-promote the first surviving row if we just removed the default.
      if @ingredient.reload.supplier_ingredients.default.empty?
        next_row = @ingredient.supplier_ingredients.first
        next_row&.promote_to_default!
      end

      render_panel
    end

    private

    def load_ingredient
      @ingredient = Current.account.ingredients.kept.find(params[:ingredient_id])
    end

    def row_params
      params.require(:supplier_ingredient).permit(:unit_cost_cents, :unit_cost, :last_bought_on).tap do |permitted|
        if permitted[:unit_cost].present?
          permitted[:unit_cost_cents] = parse_cost_to_cents(permitted.delete(:unit_cost))
        end
      end
    end

    # Accepts "32", "32.5", "1,250.00" — the operator types money the
    # Mexican way.
    def parse_cost_to_cents(raw)
      return 0 if raw.blank?
      normalized = raw.to_s.tr(",", "")
      (BigDecimal(normalized) * 100).to_i
    rescue ArgumentError
      0
    end

    def render_panel(status: :ok, error: nil)
      @ingredient.reload
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "supplier_prices_panel",
            partial: "ingredients/supplier_prices_panel",
            locals: { ingredient: @ingredient, panel_error: error }
          ), status: status
        end
        format.html { redirect_to edit_ingredient_path(@ingredient) }
      end
    end
  end
end
