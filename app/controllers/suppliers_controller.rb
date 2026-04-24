class SuppliersController < AuthenticatedController
  expose :suppliers, -> { Current.account.suppliers.kept.search(params[:q]).order(:name) }
  expose :supplier,  -> { find_or_build_supplier }

  def index; end
  def new;   end
  def edit;  end

  # Autocomplete endpoint for the ingredient form's "agregar proveedor"
  # combobox. Same pattern as ClientsController#search.
  def search
    @results = Current.account.suppliers.kept.search(params[:q]).order(:name).limit(10)
    render partial: "suppliers/search_results", locals: { results: @results }, layout: false
  end

  def create
    supplier = Current.account.suppliers.new(supplier_params)

    respond_to do |format|
      if supplier.save
        format.html { redirect_to suppliers_path, notice: t(".created") }
        format.json { render json: serialize(supplier), status: :created }
      else
        format.html { render :new, status: :unprocessable_content, locals: { supplier: supplier } }
        format.json { render json: { errors: supplier.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  def update
    if supplier.update(supplier_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(supplier),
            Suppliers::RowComponent.new(supplier: supplier)
          )
        end
        format.html { redirect_to suppliers_path, notice: t(".updated") }
      end
    else
      render :edit, status: :unprocessable_content, locals: { supplier: supplier }
    end
  end

  def destroy
    supplier.discard
    redirect_to suppliers_path, notice: t(".discarded")
  end

  private

  def find_or_build_supplier
    return Current.account.suppliers.new if params[:id].blank?
    Current.account.suppliers.kept.find(params[:id])
  end

  def supplier_params
    params.require(:supplier).permit(
      :name, :phone, :whatsapp, :rfc,
      :street_address, :colonia, :city,
      :notes
    )
  end

  def serialize(supplier)
    { id: supplier.id, label: supplier.name }
  end
end
