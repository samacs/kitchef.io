class RecipesController < AuthenticatedController
  expose :recipes, -> { Current.account.recipes.kept.order(category: :asc, position: :asc) }
  expose :recipe,  -> { find_or_build_recipe }

  def index; end
  def new;   end
  def edit;  end

  def create
    result = Recipes::Create.call(account: Current.account, params: recipe_params)
    if result.success?
      redirect_to recipes_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity, locals: { recipe: result.object }
    end
  end

  def update
    result = Recipes::Update.call(recipe: recipe, params: recipe_params)
    if result.success?
      redirect_to recipes_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity, locals: { recipe: result.object }
    end
  end

  def destroy
    recipe.discard
    redirect_to recipes_path, notice: t(".discarded")
  end

  private

  def find_or_build_recipe
    return Current.account.recipes.new if params[:id].blank?

    # URLs can arrive as either the friendly slug (from friendly_id) or
    # the prefixed id (from has_prefix_id's to_param override) depending
    # on which module's to_param ran last for a given record. Accept both.
    scope = Current.account.recipes.kept
    scope.friendly.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    scope.find(params[:id])
  end

  def recipe_params
    params.require(:recipe).permit(:name, :sale_price, :category, :description, photos: [])
  end
end
