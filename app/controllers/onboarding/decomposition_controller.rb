module Onboarding
  # First-time recipe decomposition flow. Successful submission flips
  # Current.account.settings.use_composable_recipes to true via the
  # Onboarding::CompleteFirstDecomposition command.
  class DecompositionController < AuthenticatedController
    include Subscriptions::FeatureGated
    gate_feature :composable_recipes

    before_action :load_recipe

    def show; end

    def create
      result = Onboarding::CompleteFirstDecomposition.call(
        account: Current.account,
        recipe:  @recipe,
        components_attributes: components_params
      )

      if result.success?
        redirect_to edit_recipe_path(@recipe), notice: t(".unlocked")
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def load_recipe
      scope = Current.account.recipes.kept
      @recipe = scope.friendly.find(params[:recipe_id])
    rescue ActiveRecord::RecordNotFound
      @recipe = scope.find(params[:recipe_id])
    end

    def components_params
      permitted = params.require(:recipe).permit(
        components_attributes: [
          :id, :componentable_type, :componentable_id,
          :quantity, :unit, :notes, :_destroy
        ]
      )
      raw = permitted[:components_attributes]
      return [] if raw.blank?

      raw.is_a?(Array) ? raw.map(&:to_h) : raw.to_h.values.map(&:to_h)
    rescue ActionController::ParameterMissing
      []
    end
  end
end
