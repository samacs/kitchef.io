# Phase 13 — batches (lotes) CRUD + state transitions. Gated by
# `account.inventory_enabled?`; off-accounts get a 404 because the
# feature isn't part of their UI surface at all.
class BatchesController < AuthenticatedController
  before_action :require_inventory_enabled
  before_action :load_batch, only: %i[show edit update destroy cancel complete]

  def index
    @on = parse_date(params[:on]) || Date.current
    @scope = (params[:scope].presence_in(%w[today week]) || "today").to_sym

    base = Current.account.batches.kept.includes(:recipe).order(cooked_on: :desc, created_at: :desc)

    @batches = case @scope
    when :week
      start_on = @on.beginning_of_week(:monday)
      end_on   = start_on + 6
      base.where(cooked_on: start_on..end_on)
    else
      base.where(cooked_on: @on)
    end
  end

  def new
    @batch = Current.account.batches.new(
      cooked_on: Date.current,
      planned_quantity: 1,
      recipe_id: params.dig(:batch, :recipe_id)
    )
  end

  def create
    result = Batches::Create.call(account: Current.account, params: batch_params)

    if result.success?
      flash[:notice] = t("batches.create.success")
      shortage_warning(result.object)
      redirect_to batches_path
    else
      @batch = result.object
      render :new, status: :unprocessable_content
    end
  end

  def show
  end

  def edit
  end

  def update
    if @batch.update(batch_params.slice(:notes, :available_from, :available_until))
      redirect_to batch_path(@batch), notice: t("batches.update.success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def cancel
    result = Batches::Cancel.call(batch: @batch)
    if result.success?
      redirect_to batches_path, notice: t("batches.cancel.success")
    else
      redirect_to batch_path(@batch), alert: t("batches.cancel.failure")
    end
  end

  def complete
    result = Batches::Complete.call(batch: @batch, actual_quantity: params[:actual_quantity])
    if result.success?
      redirect_to batches_path, notice: t("batches.complete.success")
    else
      redirect_to batch_path(@batch), alert: t("batches.complete.failure")
    end
  end

  def destroy
    @batch.discard
    redirect_to batches_path, notice: t("batches.destroy.success")
  end

  # Phase 13C — live impact preview. Renders just the partial inside a
  # matching `<turbo-frame>` so the new-batch form can swap in the
  # latest "te faltan X" / "todo listo" message as the operator types.
  # Returns an empty frame when no recipe is picked (the form's empty
  # state). Always 200; never redirects.
  def impact
    @recipe = Current.account.recipes.kept.find_by(id: params[:recipe_id])
    @quantity = params[:quantity].to_d
    render partial: "impact_preview", locals: { recipe: @recipe, quantity: @quantity }
  end

  private

  def require_inventory_enabled
    return if Current.account.inventory_enabled?
    raise ActionController::RoutingError, "inventory disabled"
  end

  def load_batch
    @batch = Current.account.batches.find_by_prefix_id(params[:id]) ||
           Current.account.batches.find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound if @batch.nil?
  end

  def batch_params
    params.require(:batch).permit(
      :recipe_id, :cooked_on, :available_from, :available_until,
      :planned_quantity, :notes
    )
  end

  def parse_date(raw)
    Date.iso8601(raw.to_s) if raw.present?
  rescue Date::Error
    nil
  end

  # Phase 13C — surface "te faltan X kg de Y" warnings on the flash
  # whenever a batch went into the red on any ingredient. Educational,
  # not blocking.
  def shortage_warning(batch)
    shortages = batch.consumptions.includes(:consumable).filter_map do |c|
      ing = c.consumable
      next unless ing.is_a?(Ingredient)
      next unless ing.stock_quantity.to_d.negative?
      shortfall = ing.stock_quantity.to_d.abs
      "#{ing.name} (te faltaron #{format("%.3f", shortfall).sub(/\.?0+$/, "")} #{ing.unit})"
    end
    return if shortages.empty?

    flash[:alert] = t("batches.create.shortage_warning", names: shortages.to_sentence)
  end
end
