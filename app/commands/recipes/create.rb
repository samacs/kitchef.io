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
      submitted = params.to_h.symbolize_keys
      # Treat blank strings as missing so the `||=` defaults below kick
      # in. Without this, an empty `category_id=""` from a combobox that
      # didn't capture a click bypasses the fallback and crashes the
      # `belongs_to :category` validation.
      %i[category_id yield_unit yield_quantity].each do |key|
        submitted[key] = nil if submitted[key].is_a?(String) && submitted[key].strip.empty?
      end

      # SIMPLE_DEFAULTS only fills in keys the form didn't submit. Once
      # the form ships yield_unit/yield_quantity (Phase 11+ decomposition
      # work), submissions for prep recipes pass through unchanged.
      attrs = SIMPLE_DEFAULTS.merge(submitted.compact)

      # Auto-publish when a photo is submitted AND the operator didn't
      # explicitly mark this as a draft via the form toggle.
      attrs[:is_published] = has_photo?(attrs) if attrs[:is_published].nil?

      # Fallback category for simple mode: Phase 9 replaced the enum
      # with a FK. If the form didn't submit a category, pin the
      # account's first recipe category so the save still succeeds.
      attrs[:category_id] ||= default_recipe_category_id

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

    def default_recipe_category_id
      account.categories.for_kind(:recipe).kept.order(:position, :name).pick(:id)
    end
  end
end
