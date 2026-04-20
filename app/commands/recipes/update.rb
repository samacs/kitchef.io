module Recipes
  # Updates an existing recipe with the submitted params. Simple-mode defaults
  # don't reappear here — the operator already picked them at creation time
  # and we don't want to clobber any advanced-mode tweaks a later phase will
  # let her set.
  class Update < ApplicationCommand
    option :recipe
    option :params

    def call
      if recipe.update(params.to_h)
        success(recipe)
      else
        Result.new(success: false, object: recipe, errors: recipe.errors)
      end
    end
  end
end
