class FixedCostCategoriesController < AuthenticatedController
  # POST /fixed-cost-categories
  #
  # Inline creator hit by the Ui::ComboboxComponent when the operator
  # types a new bucket in the fixed-cost drawer. Same JSON+Turbo contract
  # as CategoriesController#create, minus the `kind` dimension — all
  # fixed-cost categories live in one flat list.
  def create
    category = Current.account.fixed_cost_categories.build(
      name: params[:name].to_s.strip,
      kind: resolve_kind(params[:kind])
    )

    respond_to do |format|
      if category.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            "combobox_fixed_cost_category_options",
            partial: "fixed_cost_categories/option",
            locals: { category: category }
          )
        end
        format.json { render json: serialize(category), status: :created }
      else
        format.turbo_stream { head :unprocessable_content }
        format.json { render json: { errors: category.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  # DELETE /fixed-cost-categories/:id — guarded by restrict_with_error.
  def destroy
    category = Current.account.fixed_cost_categories.kept.find(params[:id])

    if category.usage_count.positive?
      redirect_back fallback_location: fixed_costs_path,
        alert: t(".in_use", count: category.usage_count, name: category.name)
    else
      category.discard
      redirect_back fallback_location: fixed_costs_path, notice: t(".discarded")
    end
  end

  private

  def resolve_kind(raw)
    FixedCostCategory.kinds.key?(raw.to_s) ? raw.to_s : :other
  end

  def serialize(category)
    { id: category.id, label: category.name, kind: category.kind }
  end
end
