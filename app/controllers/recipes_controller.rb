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
      render :new, status: :unprocessable_content, locals: { recipe: result.object }
    end
  end

  def update
    result = Recipes::Update.call(recipe: recipe, params: recipe_params)
    if result.success?
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_to recipes_path, notice: t(".updated") }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html { render :edit, status: :unprocessable_content, locals: { recipe: result.object } }
      end
    end
  end

  def destroy
    recipe.discard
    redirect_to recipes_path, notice: t(".discarded")
  end

  # One-click publish/unpublish from the recipe card. POSTing to this
  # endpoint flips `is_published` — if the flip is to `true` and the
  # recipe has no photo, the Update command surfaces a validation error
  # via the flash.
  def toggle_publish
    target = !recipe.is_published?
    result = Recipes::Update.call(recipe: recipe, params: { is_published: target })

    if result.success?
      redirect_to recipes_path,
        notice: t(target ? ".published" : ".unpublished", name: recipe.name)
    else
      redirect_to recipes_path,
        alert: t(".publish_requires_photo", name: recipe.name)
    end
  end

  # Bulk-publish every saleable draft that has a photo. The empty state
  # CTA on the recetario index wires to this. Silently skips photoless
  # drafts so the operator doesn't get partial-success error noise.
  def publish_all
    drafts = Current.account.recipes.kept.saleable.where(is_published: false)
    publishable = drafts.select { |r| r.photos.attached? }

    publishable.each { |r| r.update!(is_published: true) }

    count = publishable.size
    if count.zero?
      redirect_to recipes_path, alert: t(".publish_all_none")
    else
      redirect_to recipes_path, notice: t(".publish_all_ok", count: count)
    end
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
    params.require(:recipe).permit(:name, :sale_price, :category, :description, :is_published, photos: [])
  end
end
