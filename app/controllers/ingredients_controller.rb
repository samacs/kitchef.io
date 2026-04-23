class IngredientsController < AuthenticatedController
  expose :ingredients, -> { Current.account.ingredients.kept.order(category: :asc, position: :asc, name: :asc) }
  expose :ingredient,  -> { find_or_build_ingredient }

  def index; end
  def new;   end

  def edit
    # Loading the edit drawer is a read — no extra work needed.
  end

  def create
    result = Ingredients::Create.call(account: Current.account, params: ingredient_params)
    if result.success?
      redirect_to ingredients_path, notice: t(".created")
    else
      render :new, status: :unprocessable_content, locals: { ingredient: result.object }
    end
  end

  def update
    had_price_before = ingredient.unit_cost_cents
    result = Ingredients::Update.call(ingredient: ingredient, params: ingredient_params)

    if result.success?
      price_changed = had_price_before != ingredient.unit_cost_cents

      respond_to do |format|
        format.turbo_stream do
          # When the operator bumps the price, surface the impact panel
          # in the drawer. Other saves close the drawer like the Clients
          # pattern.
          if price_changed && ingredient.recipe_components.any?
            render turbo_stream: turbo_stream.update(
              "drawer_content",
              render_to_string(
                partial: "ingredients/impact_panel",
                locals: { ingredient: ingredient }
              )
            )
          else
            render turbo_stream: close_drawer_and_refresh
          end
        end
        format.html { redirect_to ingredients_path, notice: t(".updated") }
      end
    else
      render :edit, status: :unprocessable_content, locals: { ingredient: result.object }
    end
  end

  def destroy
    if ingredient.recipe_components.any?
      redirect_to ingredients_path, alert: t(".in_use", name: ingredient.name)
    else
      ingredient.discard
      redirect_to ingredients_path, notice: t(".discarded")
    end
  end

  private

  def find_or_build_ingredient
    return Current.account.ingredients.new if params[:id].blank?

    Current.account.ingredients.kept.find(params[:id])
  end

  def ingredient_params
    # Accept `unit_cost` (human decimal via money-rails) OR `unit_cost_cents`
    # (direct int). The form submits the former; tests/console may use
    # the latter.
    permitted = params.require(:ingredient).permit(
      :name, :category, :unit, :unit_cost, :unit_cost_cents, :supplier_name, :notes
    )
    permitted.delete(:unit_cost) if permitted[:unit_cost].blank? && permitted[:unit_cost_cents].present?
    permitted
  end
end
