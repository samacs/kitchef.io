class PromotionsController < AuthenticatedController
  expose :promotions, -> {
    Current.account.promotions.kept
      .order(active: :desc, created_at: :desc)
  }
  expose :promotion, -> { find_or_build_promotion }

  def index; end
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
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = t(".updated")
          render turbo_stream: [
            turbo_stream.refresh(request_id: SecureRandom.uuid),
            turbo_stream.append("flash-region", partial: "shared/flash_region")
          ]
        end
        format.html { redirect_to promotions_path, notice: t(".updated") }
      end
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
      :discount_value, :bogo_buy_quantity, :bogo_get_quantity,
      :min_order_cents, :max_discount_cents,
      :validity_mode, :starts_at, :ends_at,
      :total_usage_limit, :per_client_limit, :priority,
      :active,
      valid_weekdays: [],
      recipe_ids: [],
      category_ids: []
    )
  end
end
