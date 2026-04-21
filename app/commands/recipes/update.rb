module Recipes
  # Updates an existing recipe with the submitted params. Simple-mode defaults
  # don't reappear here — the operator already picked them at creation time
  # and we don't want to clobber any advanced-mode tweaks a later phase will
  # let her set.
  #
  # Enforces the one cross-field rule the form should honor: a recipe can
  # only be published if it has a photo attached. Attempting to publish a
  # photoless recipe returns a validation error the form re-renders.
  class Update < ApplicationCommand
    option :recipe
    option :params

    def call
      recipe.assign_attributes(params.to_h)

      if publishing_without_photo?
        recipe.errors.add(:is_published, :requires_photo)
        return Result.new(success: false, object: recipe, errors: recipe.errors)
      end

      if recipe.save
        success(recipe)
      else
        Result.new(success: false, object: recipe, errors: recipe.errors)
      end
    end

    private

    # True when this submission FLIPS the recipe to published but the
    # recipe has neither an already-attached photo nor a new one in
    # this submission.
    #
    # Guarded by `will_save_change_to_is_published?` so the validation
    # only runs at the moment of publishing — an already-published
    # recipe saved for unrelated reasons (name edit, price bump) sails
    # through even if the seed backfilled `is_published: true` without
    # attaching a photo. Operator-initiated publishing is the surface
    # we care about protecting.
    def publishing_without_photo?
      return false unless recipe.is_published?
      return false unless recipe.will_save_change_to_is_published?

      !recipe.photos.attached? &&
        Array(params[:photos]).none? { |p| p.respond_to?(:size) && p.size.positive? }
    end
  end
end
