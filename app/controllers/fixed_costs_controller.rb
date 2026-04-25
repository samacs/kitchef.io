class FixedCostsController < AuthenticatedController
  expose :fixed_costs, -> {
    Current.account.fixed_costs.kept
      .includes(:fixed_cost_category)
      .order(:start_date, :id)
  }
  expose :fixed_cost, -> { find_or_build_fixed_cost }

  def index; end
  def new;   end
  def edit;  end

  def create
    record = Current.account.fixed_costs.new(create_attrs)

    if record.save
      redirect_to fixed_costs_path, notice: t(".created")
    else
      render :new, status: :unprocessable_content, locals: { fixed_cost: record }
    end
  end

  def update
    if fixed_cost.update(fixed_cost_attrs)
      redirect_to fixed_costs_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content, locals: { fixed_cost: fixed_cost }
    end
  end

  def destroy
    fixed_cost.discard
    redirect_to fixed_costs_path, notice: t(".discarded")
  end

  private

  def find_or_build_fixed_cost
    return Current.account.fixed_costs.new(start_date: Date.current, recurrence: :monthly) if params[:id].blank?
    Current.account.fixed_costs.kept.find(params[:id])
  end

  def fixed_cost_params
    params.require(:fixed_cost).permit(
      :fixed_cost_category_id,
      :amount,
      :amount_cents,
      :cost_per_pedido,
      :cost_per_pedido_cents,
      :recurrence,
      :start_date,
      :end_date,
      :notes
    )
  end

  def create_attrs
    fixed_cost_attrs
  end

  # Accept peso inputs like "15000" or "15,000.50" on the way in and
  # normalize to integer cents once. Same trick Orders use with
  # `unit_price` → `unit_price_cents`.
  def fixed_cost_attrs
    permitted = fixed_cost_params.to_h

    if (raw = permitted.delete("amount")).present?
      permitted["amount_cents"] = pesos_to_cents(raw)
    end

    raw_per_pedido = permitted.delete("cost_per_pedido")
    if raw_per_pedido.present?
      permitted["cost_per_pedido_cents"] = pesos_to_cents(raw_per_pedido)
    elsif raw_per_pedido == ""
      # Operator cleared the field — drop the per-pedido flavor entirely.
      permitted["cost_per_pedido_cents"] = nil
    end

    permitted["end_date"] = nil if permitted["end_date"].blank?
    permitted
  end

  def pesos_to_cents(raw)
    normalized = raw.to_s.gsub(",", "").gsub(/[^\d.\-]/, "").to_d
    (normalized * 100).to_i
  end
end
