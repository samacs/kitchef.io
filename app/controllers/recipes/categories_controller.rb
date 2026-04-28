class Recipes::CategoriesController < AuthenticatedController
  # GET /recipes/categories
  def index
    @categories = Current.account.categories.kept.recipe
      .order(:position, :name)
      .includes(:recipes)
  end

  # GET /recipes/categories/:id/edit_form
  def edit_form
    @category = Current.account.categories.kept.recipe.find(params[:id])
    render partial: "recipes/categories/edit_form", locals: { category: @category }
  end

  # PATCH /recipes/categories/:id
  def update
    category = Current.account.categories.kept.recipe.find(params[:id])

    if category.update(category_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(category),
            partial: "recipes/categories/row",
            locals: { category: category }
          )
        end
        format.html { redirect_to recipes_categories_path, notice: t(".updated") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(category),
            partial: "recipes/categories/edit_form",
            locals: { category: category }
          )
        end
        format.html { redirect_to recipes_categories_path, alert: category.errors.full_messages.first }
      end
    end
  end

  # PATCH /recipes/categories/reorder
  def reorder
    ids = params[:ids]
    unless ids.is_a?(Array)
      head :unprocessable_content
      return
    end

    Category.transaction do
      ids.each_with_index do |id, idx|
        Current.account.categories.kept.recipe.where(id: id).update_all(position: idx)
      end
    end

    head :ok
  end

  # DELETE /recipes/categories/:id
  def destroy
    category = Current.account.categories.kept.recipe.find(params[:id])

    if category.usage_count.positive?
      redirect_to recipes_categories_path,
        alert: t(".in_use", count: category.usage_count, name: category.name)
    else
      category.discard
      redirect_to recipes_categories_path, notice: t(".discarded")
    end
  end

  private

  def category_params
    params.require(:category).permit(:name)
  end
end
