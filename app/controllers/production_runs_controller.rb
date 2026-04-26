# Phase 13 — production runs (tandas) CRUD + state transitions. Gated
# by `account.inventory_enabled?`; off-accounts get a 404 because the
# feature isn't part of their UI surface at all.
class ProductionRunsController < AuthenticatedController
  before_action :require_inventory_enabled
  before_action :load_run, only: %i[show edit update destroy cancel complete]

  def index
    @on = parse_date(params[:on]) || Date.current
    @scope = (params[:scope].presence_in(%w[today week]) || "today").to_sym

    base = Current.account.production_runs.kept.includes(:recipe).order(cooked_on: :desc, created_at: :desc)

    @runs = case @scope
    when :week
              start_on = @on.beginning_of_week(:monday)
              end_on   = start_on + 6
              base.where(cooked_on: start_on..end_on)
    else
              base.where(cooked_on: @on)
    end
  end

  def new
    @run = Current.account.production_runs.new(
      cooked_on: Date.current,
      planned_quantity: 1
    )
  end

  def create
    result = Production::StartRun.call(account: Current.account, params: run_params)

    if result.success?
      redirect_to production_runs_path, notice: t("production.runs.create.success")
    else
      @run = result.object
      render :new, status: :unprocessable_content
    end
  end

  def show
  end

  def edit
  end

  def update
    if @run.update(run_params.slice(:notes, :available_from, :available_until))
      redirect_to production_run_path(@run), notice: t("production.runs.update.success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def cancel
    result = Production::CancelRun.call(run: @run)
    if result.success?
      redirect_to production_runs_path, notice: t("production.runs.cancel.success")
    else
      redirect_to production_run_path(@run), alert: t("production.runs.cancel.failure")
    end
  end

  def complete
    result = Production::CompleteRun.call(run: @run, actual_quantity: params[:actual_quantity])
    if result.success?
      redirect_to production_runs_path, notice: t("production.runs.complete.success")
    else
      redirect_to production_run_path(@run), alert: t("production.runs.complete.failure")
    end
  end

  def destroy
    @run.discard
    redirect_to production_runs_path, notice: t("production.runs.destroy.success")
  end

  private

  def require_inventory_enabled
    return if Current.account.inventory_enabled?
    raise ActionController::RoutingError, "inventory disabled"
  end

  def load_run
    @run = Current.account.production_runs.find_by_prefix_id(params[:id]) ||
           Current.account.production_runs.find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound if @run.nil?
  end

  def run_params
    params.require(:production_run).permit(
      :recipe_id, :cooked_on, :available_from, :available_until,
      :planned_quantity, :notes
    )
  end

  def parse_date(raw)
    Date.iso8601(raw.to_s) if raw.present?
  rescue Date::Error
    nil
  end
end
