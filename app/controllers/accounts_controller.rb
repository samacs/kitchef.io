class AccountsController < AuthenticatedController
  before_action :guard_pro_only_settings, only: :update

  def show
    redirect_to edit_account_path
  end

  def edit
    @account = Current.account
  end

  def update
    inventory_was_enabled = Current.account.inventory_enabled?
    result = Accounts::Update.call(
      account:     Current.account,
      attributes:  account_params,
      logo:        params.dig(:account, :logo),
      cover_photo: params.dig(:account, :cover_photo)
    )

    if result.success?
      Current.account.reload
      first_inventory_opt_in = !inventory_was_enabled && Current.account.inventory_enabled?

      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html do
          if first_inventory_opt_in
            redirect_to batches_onboarding_path
          else
            redirect_to edit_account_path, notice: t("account.saved")
          end
        end
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

  # Phase 14, Slice 5 — physical "Borrar mi cuenta" zona peligrosa.
  # Operator must type her kitchen name as the confirmation token; if
  # it matches, we hard-delete the account + everything under it AND
  # the owner's User row (via Account#users cascade), then sign her
  # out. No undo, no soft-delete preserved. Stripe-side cleanup
  # (cancel paying subscription) is handled inside Accounts::Destroy.
  def destroy
    confirmation = params[:confirmation_name].to_s.strip
    if confirmation != Current.account.name
      redirect_to subscription_path,
                  alert: t("account.destroy.name_mismatch", name: Current.account.name)
      return
    end

    result = Accounts::Destroy.call(
      account:        Current.account,
      acted_by_user:  Current.user
    )

    if result.success?
      reset_session
      redirect_to root_path, notice: t("account.destroy.success")
    else
      redirect_to subscription_path,
                  alert: t("account.destroy.failure", message: result.errors.to_a.first)
    end
  end

  private

  # Defense in depth: the inventory toggle is locked in the UI for Free
  # accounts, but a hand-crafted POST could still try to flip it to
  # `true`. If a Free user attempts to enable a Pro-only setting, 422
  # the whole update so nothing else in the form sneaks through with
  # an invalid feature flag set.
  def guard_pro_only_settings
    inv = params.dig(:account, :settings, :inventory_settings, :enabled)
    return if inv.blank?
    return if ActiveModel::Type::Boolean.new.cast(inv) == false
    return if Entitlements.for(Current.account).allows?(:inventory)

    @account = Current.account
    flash.now[:alert] = t("account.pro_only_setting_blocked")
    respond_to do |format|
      format.turbo_stream { head :payment_required }
      format.html { render :edit, status: :payment_required }
    end
  end

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
        fulfillment_pickup fulfillment_delivery
      ],
      settings: [
        :default_packaging, :default_packaging_cents,
        { payment_settings: %i[
          accepts_cash accepts_transfer accepts_card
          transfer_holder transfer_bank transfer_clabe transfer_account_number
          card_instructions
          accepts_tips
        ] + [ tip_presets_pct: [] ] },
        { inventory_settings: %i[
          enabled oversell_policy
          low_stock_threshold_pct default_batch_window_days
        ] }
      ]
    ).then { |p| normalize_settings_packaging(p) }
     .then { |p| normalize_payment_settings(p) }
     .then { |p| normalize_inventory_settings(p) }
     .then { |p| normalize_public_profile(p) }
     .then { |p| normalize_address_coords(p) }
  end

  def normalize_settings_packaging(permitted)
    return permitted unless permitted[:settings]&.key?(:default_packaging)
    raw = permitted[:settings].delete(:default_packaging)
    return permitted if raw.blank?
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

  def normalize_inventory_settings(permitted)
    inv = permitted.dig(:settings, :inventory_settings)
    return permitted if inv.blank?

    if inv.key?(:enabled)
      inv[:enabled] = ActiveModel::Type::Boolean.new.cast(inv[:enabled])
    end

    %i[low_stock_threshold_pct default_batch_window_days].each do |key|
      inv[key] = inv[key].to_i if inv.key?(key) && inv[key].present?
    end

    permitted
  end

  def normalize_public_profile(permitted)
    pp = permitted[:public_profile]
    return permitted if pp.blank?

    if pp.key?(:show_pickup_address)
      pp[:show_pickup_address] = ActiveModel::Type::Boolean.new.cast(pp[:show_pickup_address])
    end

    if pp.key?(:fulfillment_pickup) || pp.key?(:fulfillment_delivery)
      types = []
      types << "pickup"   if ActiveModel::Type::Boolean.new.cast(pp.delete(:fulfillment_pickup))
      types << "delivery" if ActiveModel::Type::Boolean.new.cast(pp.delete(:fulfillment_delivery))
      pp[:fulfillment_types] = types.join(",")
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
