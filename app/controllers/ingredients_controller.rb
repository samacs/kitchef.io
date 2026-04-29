class IngredientsController < AuthenticatedController
  expose :ingredients, -> {
    Current.account.ingredients.kept
      .includes(:category)
      .order(category_id: :asc, position: :asc, name: :asc)
  }
  expose :ingredient,  -> { find_or_build_ingredient }

  def index; end
  def new;   end

  def edit
    # Loading the edit drawer is a read — no extra work needed.
  end

  def create
    result = Ingredients::Create.call(account: Current.account, params: create_attrs)

    respond_to do |format|
      if result.success?
        format.html { redirect_to ingredients_path, notice: t(".created") }
        format.json { render json: serialize(result.object), status: :created }
      else
        format.html { render :new, status: :unprocessable_content, locals: { ingredient: result.object } }
        format.json { render json: { errors: result.object.errors.full_messages }, status: :unprocessable_content }
      end
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

    resolve_record(Current.account.ingredients.kept) ||
      raise(ActiveRecord::RecordNotFound)
  end

  def ingredient_params
    # Accept `unit_cost` (human decimal via money-rails) OR `unit_cost_cents`
    # (direct int). The form submits the former; tests/console may use
    # the latter.
    permitted = params.require(:ingredient).permit(
      :name, :category_id, :unit, :unit_cost, :unit_cost_cents, :notes
    )
    permitted.delete(:unit_cost) if permitted[:unit_cost].blank? && permitted[:unit_cost_cents].present?
    permitted
  end

  # Accept both shapes:
  #   * Nested (regular form):    `ingredient[name]=…&ingredient[unit]=…`
  #   * Flat (combobox JSON POST): `name=…` — operator types a new
  #     ingredient straight into the Ui::ComboboxComponent picker on
  #     the purchase form. We seed a sensible default unit (kg — the
  #     most common market purchase unit) and let `Ingredients::Create`
  #     pin the first category. She edits the rest later from
  #     /ingredients.
  def create_attrs
    if params[:ingredient].present?
      ingredient_params
    else
      { name: params.require(:name).to_s.strip, unit: "kg" }
    end
  end

  def serialize(ingredient)
    { id: ingredient.id, label: ingredient.name }
  end
end
