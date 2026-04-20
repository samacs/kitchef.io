class ClientsController < AuthenticatedController
  expose :clients, -> { Current.account.clients.kept.search(params[:q]).order(:first_name, :last_name) }
  expose :client,  -> { find_or_build_client }

  def index; end
  def new;   end
  def edit;  end

  # Autocomplete endpoint hit by the order form's client picker. Returns a
  # bare HTML partial (no layout, no Turbo Drive) — the Stimulus controller
  # injects the result list into a popover.
  def search
    @results = Current.account.clients.kept.search(params[:q]).order(:first_name, :last_name).limit(10)
    render partial: "clients/search_results", locals: { results: @results }, layout: false
  end

  def create
    result = Clients::Create.call(account: Current.account, params: client_params)

    respond_to do |format|
      if result.success?
        format.html { redirect_to clients_path, notice: t(".created") }
        format.json { render json: client_json(result.object), status: :created }
      else
        format.html { render :new, status: :unprocessable_entity, locals: { client: result.object } }
        format.json { render json: { errors: result.object.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    result = Clients::Update.call(client: client, params: client_params)
    if result.success?
      respond_to do |format|
        format.turbo_stream { render turbo_stream: close_drawer_and_refresh }
        format.html { redirect_to clients_path, notice: t(".updated") }
      end
    else
      render :edit, status: :unprocessable_entity, locals: { client: result.object }
    end
  end

  def destroy
    client.discard
    redirect_to clients_path, notice: t(".discarded")
  end

  private

  def find_or_build_client
    return Current.account.clients.new if params[:id].blank?

    Current.account.clients.kept.find(params[:id])
  end

  def client_params
    params.require(:client).permit(
      :first_name, :last_name, :phone, :email,
      :colonia, :city, :street_address, :notes
    )
  end

  def client_json(client)
    {
      id:             client.id,
      name:           client.name,
      colonia:        client.colonia,
      city:           client.city,
      street_address: client.street_address
    }
  end
end
