class RecipesController < AuthenticatedController
  expose :recipes, -> { Current.account.recipes.kept.includes(:category).order(category_id: :asc, position: :asc) }
  expose :recipe,  -> { find_or_build_recipe }

  def index; end
  def new;   end
  def edit;  end

  # Read-only detail surface: name + photo + sale price + cost tree.
  # The `/recipes` index links recipe cards to `#edit`; the cost tree
  # is its own URL so the operator can share a link to "here's what
  # this dish costs me to make" with her sous-chef or her accountant.
  def show
    @cost_tree_root = Recipes::CostTreeNode.build(recipe: recipe)
  end

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
      # Recompute cost inline so the turbo-stream response carries the
      # fresh number. The async RecipeCostRefreshJob still fires from
      # RecipeComponent callbacks for fan-out, but for the submitter's
      # own page we want the summary hot without waiting on Sidekiq.
      Recipes::CostCalculator.for(recipe: recipe)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "recipe_cost_summary",
            partial: "recipes/cost_summary",
            locals: { recipe: recipe }
          )
        end
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

  # Bulk margin reprice triggered from the ingredient impact panel.
  # Takes either an ingredient (fan out via DependencyGraph) or an
  # explicit list of recipe ids. Account-scoped: a stray id from
  # another tenant is silently filtered.
  def rescale_for_margin
    ingredient = Current.account.ingredients.find_by(id: params[:ingredient_id]) if params[:ingredient_id].present?
    recipe_ids = Current.account.recipes.where(id: Array(params[:recipe_ids])).pluck(:id)

    result = Recipes::RescaleForMargin.call(
      ingredient: ingredient,
      recipe_ids: recipe_ids.presence
    )

    redirect_to ingredients_path, notice: t(".rescaled", count: result.object)
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
    params.require(:recipe).permit(
      :name, :sale_price, :category_id, :description, :is_published,
      :is_saleable, :yield_quantity, :yield_unit, :target_margin_percent,
      photos: [],
      components_attributes: [
        :id, :componentable_type, :componentable_id,
        :quantity, :unit, :notes, :position, :is_removable, :_destroy
      ],
      option_groups_attributes: [
        :id, :account_id, :label, :sub, :kind, :required, :position, :max_length, :_destroy,
        options_attributes: [
          :id, :label, :sub, :price_delta, :is_default, :color_hex, :position, :_destroy
        ]
      ]
    ).then { |p| normalize_option_price_deltas(p) }
  end

  def normalize_option_price_deltas(permitted)
    groups = permitted[:option_groups_attributes]
    return permitted unless groups

    groups.each_value do |group_attrs|
      group_attrs[:account_id] ||= Current.account.id
      opts = group_attrs[:options_attributes]
      next unless opts

      opts.each_value do |opt_attrs|
        raw = opt_attrs.delete(:price_delta)
        next if raw.blank?
        normalized = raw.to_s.gsub(",", ".").to_d
        opt_attrs[:price_delta_cents] = (normalized * 100).to_i
      end
    end

    permitted
  end
end
