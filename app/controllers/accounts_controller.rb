class AccountsController < AuthenticatedController
  def show
    redirect_to edit_account_path
  end

  def edit
    @account = Current.account
  end

  def update
    result = Accounts::Update.call(
      account:     Current.account,
      attributes:  account_params,
      logo:        params.dig(:account, :logo),
      cover_photo: params.dig(:account, :cover_photo)
    )

    if result.success?
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_to edit_account_path, notice: t("account.saved") }
      end
    else
      @account = result.object
      respond_to do |format|
        format.html do
          flash.now[:alert] = t("account.save_error")
          render :edit, status: :unprocessable_content
        end
      end
    end
  end

  def destroy_logo
    Current.account.logo.purge_later if Current.account.logo.attached?
    redirect_to edit_account_path, notice: t("account.logo_removed")
  end

  def destroy_cover
    Current.account.cover_photo.purge_later if Current.account.cover_photo.attached?
    redirect_to edit_account_path, notice: t("account.cover_removed")
  end

  private

  def account_params
    params.require(:account).permit(
      :name,
      :street_address, :latitude, :longitude,
      branding:       %i[palette secondary_palette],
      public_profile: %i[
        tagline description
        phone whatsapp instagram
        colonia city
        delivery_zones payment_notes pickup_reminder_hours
        show_pickup_address
      ],
      settings: [
        :default_packaging, :default_packaging_cents,
        { payment_settings: %i[
          accepts_cash accepts_transfer accepts_card
          transfer_holder transfer_bank transfer_clabe transfer_account_number
          card_instructions
          accepts_tips
        ] + [ tip_presets_pct: [] ] }
      ]
    ).then { |p| normalize_settings_packaging(p) }
     .then { |p| normalize_payment_settings(p) }
     .then { |p| normalize_public_profile(p) }
     .then { |p| normalize_address_coords(p) }
  end

  def normalize_settings_packaging(permitted)
    raw = permitted.dig(:settings, :default_packaging)
    return permitted if raw.blank?
    permitted[:settings].delete(:default_packaging)
    normalized = raw.to_s.gsub(",", ".").to_d
    permitted[:settings][:default_packaging_cents] = (normalized * 100).to_i
    permitted
  end

  def normalize_payment_settings(permitted)
    ps = permitted.dig(:settings, :payment_settings)
    return permitted if ps.blank?

    if ps[:tip_presets_pct].is_a?(Array)
      ps[:tip_presets_pct] = ps[:tip_presets_pct].filter_map { |v| v.to_i if v.present? }
    end

    %i[accepts_cash accepts_transfer accepts_card accepts_tips].each do |key|
      ps[key] = ActiveModel::Type::Boolean.new.cast(ps[key]) if ps.key?(key)
    end

    permitted
  end

  def normalize_public_profile(permitted)
    pp = permitted[:public_profile]
    return permitted if pp.blank?

    if pp.key?(:show_pickup_address)
      pp[:show_pickup_address] = ActiveModel::Type::Boolean.new.cast(pp[:show_pickup_address])
    end

    permitted
  end

  # The Google Places autocomplete + draggable marker on /account/edit
  # populates hidden lat/lon fields. Empty strings ("") would otherwise
  # arrive as 0.0 after AR's decimal cast — turn them into nil so the
  # account stays "ungeocoded" cleanly.
  def normalize_address_coords(permitted)
    %i[latitude longitude].each do |key|
      next unless permitted.key?(key)
      val = permitted[key].to_s.strip
      permitted[key] = val.empty? ? nil : val
    end
    permitted
  end
end
