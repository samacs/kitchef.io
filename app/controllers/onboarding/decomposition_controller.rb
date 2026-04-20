module Onboarding
  # First-time recipe decomposition flow. Landing on this controller is
  # what flips Current.account.settings.use_composable_recipes to true.
  class DecompositionController < AuthenticatedController
    def show
      render_stub(title: t("onboarding.decomposition.title"),
        meta: "onboarding/decomposition#show — recipe_id=#{params[:recipe_id]}")
    end

    def create
      render_stub(title: t("onboarding.decomposition.title"),
        meta: "onboarding/decomposition#create")
    end
  end
end
