require "csv"

class PurchasesController < AuthenticatedController
  expose :purchases, -> {
    Current.account.purchases.kept.includes(:supplier, items: :ingredient).recent
  }
  expose :purchase, -> { find_or_build_purchase }

  def index
    respond_to do |format|
      format.html
      format.csv do
        send_data build_csv,
          filename: "compras-#{Date.current.iso8601}.csv",
          type: "text/csv; charset=utf-8"
      end
    end
  end

  def new
    # Seed one blank line so the form renders with a row ready to fill.
    @purchase = Current.account.purchases.new(purchased_on: Date.current)
    @purchase.items.new
  end

  def show; end
  def edit; end

  def create
    result = Purchases::Create.call(
      account: Current.account,
      params: purchase_params.except(:receipt_photo),
      receipt_photo: purchase_params[:receipt_photo]
    )

    if result.success?
      redirect_to purchases_path, notice: t(".created", total: helpers.humanized_money_with_symbol(result.object.total))
    else
      @purchase = result.object
      render :new, status: :unprocessable_content, locals: { purchase: @purchase }
    end
  end

  def update
    purchase.receipt_photo.attach(purchase_params[:receipt_photo]) if purchase_params[:receipt_photo].present?

    if purchase.update(purchase_params.except(:receipt_photo))
      redirect_to purchase_path(purchase), notice: t(".updated")
    else
      render :edit, status: :unprocessable_content, locals: { purchase: purchase }
    end
  end

  def destroy
    purchase.discard
    redirect_to purchases_path, notice: t(".discarded")
  end

  private

  def find_or_build_purchase
    return Current.account.purchases.new(purchased_on: Date.current) if params[:id].blank?
    Current.account.purchases.kept.find(params[:id])
  end

  def purchase_params
    params.require(:purchase).permit(
      :purchased_on, :supplier_id, :total_override, :notes, :receipt_photo,
      items_attributes: [
        :id, :ingredient_id, :quantity, :unit, :unit_cost, :unit_cost_cents,
        :notes, :position, :_destroy
      ]
    )
  end

  def build_csv
    CSV.generate(write_headers: true, force_quotes: true) do |csv|
      csv << [
        t("purchases.csv.headers.date"),
        t("purchases.csv.headers.supplier"),
        t("purchases.csv.headers.ingredient"),
        t("purchases.csv.headers.quantity"),
        t("purchases.csv.headers.unit"),
        t("purchases.csv.headers.unit_cost"),
        t("purchases.csv.headers.subtotal"),
        t("purchases.csv.headers.notes")
      ]
      purchases.each do |purchase|
        purchase.items.each do |item|
          csv << [
            purchase.purchased_on.iso8601,
            purchase.supplier_name || t("purchases.no_supplier"),
            item.ingredient.name,
            item.quantity.to_s,
            I18n.t("units.#{item.unit}", default: item.unit),
            format("%.2f", item.unit_cost_cents / 100.0),
            format("%.2f", item.subtotal_cents / 100.0),
            item.notes
          ]
        end
      end
    end.then { |body| "\uFEFF" + body }  # BOM so Excel on es-MX opens cleanly
  end
end
