class RecipesController < AuthenticatedController
  expose :recipes, -> { Current.account.recipes.kept.includes(:category).order(category_id: :asc, position: :asc) }
  expose :recipe,  -> { find_or_build_recipe }

  def index
    # Surface the archive count next to the index header so a freshly-
    # discarded platillo is one click away from coming back.
    @archived_count = Current.account.recipes.discarded.count
  end
  def new;   end
  def edit;  end

  # Archive — lists every soft-deleted recipe so the operator can restore
  # one. Includes both saleable and internal recipes; sorted most-recently-
  # discarded first so the latest mistake is easiest to spot.
  def archived
    @archived_recipes = Current.account.recipes.discarded
      .includes(:category)
      .order(discarded_at: :desc)
  end

  # POST /recipes/:id/restore — un-discards a soft-deleted recipe and
  # leaves it as a draft (the model's discard column is the only state
  # that flips). Lands the operator back on the index with a confirmation.
  def restore
    target = resolve_record(Current.account.recipes.discarded)

    if target
      target.undiscard
      redirect_to recipes_path, notice: t(".restored", name: target.name)
    else
      redirect_to archived_recipes_path, alert: t(".not_found")
    end
  end

  # POST /recipes/:id/duplicate — clones the recipe (components + option
  # groups) into a fresh draft and lands the operator on its edit page.
  # The copy starts unpublished so she can rename + tweak before exposing.
  def duplicate
    result = Recipes::Duplicate.call(recipe: recipe)
    if result.success?
      redirect_to edit_recipe_path(result.object),
        notice: t(".duplicated", name: result.object.name)
    else
      redirect_to recipes_path, alert: result.errors.full_messages.to_sentence
    end
  end

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
          # Replace BOTH the cost summary AND the components rows. The
          # rows replacement is load-bearing — without it, freshly-added
          # rows in the DOM still have an empty `id` field and the next
          # autosave creates a duplicate component in the DB. Re-rendering
          # the rows server-side fills in the persisted IDs so subsequent
          # saves UPDATE the same record instead of inserting again.
          render turbo_stream: [
            turbo_stream.replace(
              "recipe_cost_summary",
              partial: "recipes/cost_summary",
              locals: { recipe: recipe }
            ),
            turbo_stream.replace(
              "recipe_components_rows",
              partial: "recipes/components_rows",
              locals: { recipe: recipe }
            )
          ]
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

    resolve_record(Current.account.recipes.kept) ||
      raise(ActiveRecord::RecordNotFound)
  end

  def recipe_params
    params.require(:recipe).permit(
      :name, :sale_price, :category_id, :description, :is_published,
      :is_saleable, :yield_quantity, :yield_unit, :target_margin_percent, :lead_time_hours,
      # Phase 14, Slice 12 — multi-photo fields. `photos[]` stays for
      # the legacy single-photo path; `new_photos[]` is the multi-tile
      # grid's file input; `remove_photo_ids` is a CSV of attachment
      # ids the operator clicked X on; `photo_order` is the JSON
      # array driving the on-save reorder. All four are stripped from
      # params inside Recipes::Update before `assign_attributes`.
      :remove_photo_ids, :photo_order,
      photos:     [],
      new_photos: [],
      components_attributes: [
        :id, :componentable_type, :componentable_id,
        :quantity, :unit, :notes, :position, :is_removable, :is_byproduct, :_destroy
      ],
      option_groups_attributes: [
        :id, :account_id, :label, :sub, :kind, :required, :position, :max_length,
        :selection_mode, :unit_count, :_destroy,
        options_attributes: [
          :id, :label, :sub, :price_delta, :is_default, :color_hex, :position,
          :componentable_type, :componentable_id, :componentable_ref,
          :quantity, :unit, :_destroy
        ]
      ]
    ).then { |p| normalize_sale_price(p) }
     .then { |p| normalize_option_price_deltas(p) }
  end

  # money-rails adds a numericality validator on the `sale_price` virtual
  # attribute that fires even for internal (non-saleable) recipes. When
  # the autosave form serialises ALL fields, the sale_price field of an
  # internal recipe arrives as "" — which money-rails rejects as
  # `not_a_number`. Normalise blank to nil so the validator skips it.
  def normalize_sale_price(permitted)
    if permitted[:sale_price].present? == false
      permitted.delete(:sale_price)
    end
    permitted
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
        if raw.present?
          normalized = raw.to_s.gsub(",", ".").to_d
          opt_attrs[:price_delta_cents] = (normalized * 100).to_i
        end

        opt_attrs.delete(:componentable_ref)

        if opt_attrs[:componentable_type].blank? || opt_attrs[:componentable_id].blank?
          opt_attrs[:componentable_type] = nil
          opt_attrs[:componentable_id] = nil
          opt_attrs[:quantity] = nil
          opt_attrs[:unit] = nil
        end
      end
    end

    permitted
  end
end
