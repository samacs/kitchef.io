module Recipes
  # Creates a saleable recipe in simple mode. Applies the invisible-in-the-form
  # defaults server-side so the Phase 2B form can stay focused on the four
  # fields the operator actually fills in (name, price, category, description)
  # plus the photo upload.
  #
  # Auto-publishes the recipe when the operator includes a photo in the
  # submission — the 90%-case operator creates a dish intending to sell it,
  # so `is_published: true` is the friendlier default than leaving the
  # recipe as a silent draft that never appears on her storefront. If she
  # doesn't upload a photo yet (still shopping for the right one), the
  # recipe lands as a draft and she can publish explicitly later.
  #
  # On failure, returns the invalid recipe as `result.object` so the controller
  # can re-render the form with the submitted values.
  class Create < ApplicationCommand
    option :account
    option :params

    SIMPLE_DEFAULTS = {
      is_saleable:           true,
      yield_quantity:        1,
      yield_unit:            "piece",
      target_margin_percent: 60
    }.freeze

    def call
      attrs = SIMPLE_DEFAULTS.merge(params.to_h)
      # Auto-publish when a photo is submitted AND the operator didn't
      # explicitly mark this as a draft via the form toggle.
      attrs[:is_published] = has_photo?(attrs) if attrs[:is_published].nil?

      recipe = account.recipes.new(attrs)
      if recipe.save
        success(recipe)
      else
        Result.new(success: false, object: recipe, errors: recipe.errors)
      end
    end

    private

    def has_photo?(attrs)
      photos = attrs[:photos]
      return false if photos.blank?

      Array(photos).any? { |p| p.respond_to?(:size) && p.size.positive? }
    end
  end
end
