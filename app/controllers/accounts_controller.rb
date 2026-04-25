class AccountsController < AuthenticatedController
  # Post-onboarding kitchen configuration. One page, autosave on every
  # field change. Reached from the sidebar "Ajustes" item.
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
      # Autosave-friendly response: 204 No Content. Turbo fires a
      # `turbo:submit-end` with success=true, which
      # `form_autosave_controller` uses to flip the status indicator
      # to "Guardado" — without a redirect that would reload the form
      # and reset scroll / in-flight typing. For hard-navigation
      # fallbacks (e.g. a browser without Turbo), respond HTML too so
      # the operator still lands on the edit page.
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_to edit_account_path, notice: t("account.saved") }
      end
    else
      @account = result.object
      respond_to do |format|
        # Turbo: re-render the form inline so field-level validation
        # errors surface where the operator is typing. Status 422 makes
        # Turbo treat the submit as unsuccessful (error state on the
        # indicator) but keeps the DOM swap.
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
      branding:       %i[palette secondary_palette],
      public_profile: %i[
        tagline description
        phone whatsapp instagram
        colonia city
        delivery_zones payment_notes pickup_reminder_hours
      ],
      settings: %i[default_packaging default_packaging_cents]
    ).then { |p| normalize_settings_packaging(p) }
  end

  def normalize_settings_packaging(permitted)
    raw = permitted.dig(:settings, :default_packaging)
    return permitted if raw.blank?
    permitted[:settings].delete(:default_packaging)
    normalized = raw.to_s.gsub(",", ".").to_d
    permitted[:settings][:default_packaging_cents] = (normalized * 100).to_i
    permitted
  end
end
