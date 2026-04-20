module Onboarding
  class KitchensController < BaseController
    # POST /onboarding/slug-check — called by the slug editor Stimulus
    # controller on every debounced keystroke. Returns JSON so the UI can
    # paint availability next to the input in real time.
    skip_before_action :verify_authenticity_token, only: :slug_check, if: -> { request.format.json? }

    def new
      @form = kitchen_form
    end

    def create
      result = if current_onboarding_account
        UpdateKitchen.call(
          account: current_onboarding_account,
          name:    params.dig(:account, :name),
          slug:    params.dig(:account, :slug)
        )
      else
        CreateAccount.call(
          user: Current.user,
          name: params.dig(:account, :name),
          slug: params.dig(:account, :slug)
        )
      end

      if result.success?
        redirect_to onboarding_description_path
      else
        @form   = kitchen_form
        @errors = result.errors
        render :new, status: :unprocessable_entity
      end
    end

    # JSON — live slug availability check. Intentionally forgiving: we
    # normalize the candidate through the same rules the Account model
    # uses, so the operator sees the exact slug her kitchen will ship
    # with.
    def slug_check
      raw       = params[:slug].to_s
      fallback  = params[:name].to_s
      candidate = Account.slugify(raw.presence || fallback)

      if candidate.blank?
        return render json: { ok: false, slug: "", reason: "blank" }
      end

      render json: {
        ok:     slug_available?(candidate),
        slug:   candidate,
        reason: slug_unavailability_reason(candidate)
      }
    end

    private

    def kitchen_form
      if current_onboarding_account
        {
          name: params.dig(:account, :name) || current_onboarding_account.name,
          slug: params.dig(:account, :slug) || current_onboarding_account.slug
        }
      else
        {
          name: params.dig(:account, :name).to_s,
          slug: params.dig(:account, :slug).to_s
        }
      end
    end

    def slug_available?(candidate)
      slug_unavailability_reason(candidate).nil?
    end

    def slug_unavailability_reason(candidate)
      return "format"   unless candidate.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
      return "length"   if candidate.length < 3 || candidate.length > 50
      return "reserved" if Account::RESERVED_SLUGS.include?(candidate)
      return "taken"    if slug_taken?(candidate)

      nil
    end

    def slug_taken?(candidate)
      scope = Account.where(slug: candidate)
      scope = scope.where.not(id: current_onboarding_account.id) if current_onboarding_account
      scope.exists?
    end
  end
end
