class PromotionsController < AuthenticatedController
  expose :promotions, -> {
    Current.account.promotions.kept
      .order(active: :desc, created_at: :desc)
  }
  expose :promotion, -> { find_or_build_promotion }

  def index
    @performance = Promotions::Performance.call(account: Current.account)
  end
  def new;   end
  def edit;  end

  def create
    result = Promotions::Create.call(account: Current.account, params: promotion_params)
    if result.success?
      redirect_to promotions_path, notice: t(".created")
    else
      render :new, status: :unprocessable_content, locals: { promotion: result.object }
    end
  end

  def update
    result = Promotions::Update.call(promotion: promotion, params: promotion_params)
    if result.success?
      redirect_to promotions_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content, locals: { promotion: result.object }
    end
  end

  def destroy
    promotion.discard
    redirect_to promotions_path, notice: t(".discarded")
  end

  def toggle
    result = Promotions::Toggle.call(promotion: promotion)
    if result.success?
      redirect_to promotions_path,
        notice: t(promotion.active? ? ".activated" : ".deactivated", name: promotion.name)
    else
      redirect_to promotions_path, alert: result.errors.full_messages.to_sentence
    end
  end

  private

  def find_or_build_promotion
    return Current.account.promotions.new if params[:id].blank?

    resolve_record(Current.account.promotions.kept) ||
      raise(ActiveRecord::RecordNotFound)
  end

  def promotion_params
    params.require(:promotion).permit(
      :name, :code, :kind, :discount_type, :scope_type,
      :discount_value, :discount_value_pesos,
      :badge_label, :badge_color,
      :bogo_buy_quantity, :bogo_get_quantity,
      :min_order_pesos, :max_discount_pesos,
      :validity_mode, :starts_at, :ends_at,
      :total_usage_limit, :per_client_limit, :priority,
      :active,
      valid_weekdays: [],
      recipe_ids: [],
      category_ids: []
    ).then { |p| normalize_money_fields(p) }
  end

  def normalize_money_fields(permitted)
    pesos_to_cents(permitted, :discount_value_pesos, :discount_value)
    pesos_to_cents(permitted, :min_order_pesos, :min_order_cents)
    pesos_to_cents(permitted, :max_discount_pesos, :max_discount_cents)
    permitted
  end

  def pesos_to_cents(permitted, peso_key, cents_key)
    raw = permitted.delete(peso_key)
    return if raw.blank?
    permitted[cents_key] = (raw.to_s.gsub(",", ".").to_d * 100).to_i
  end
end
