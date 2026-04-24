module Recipes
  # Whole "Componentes" block on the recipe edit page. Lists every
  # component as a row with quantity + unit + name + line cost, plus a
  # picker at the bottom that surfaces ingredients (always safe) and
  # recipes (filtered through Recipes::DependencyGraph to hide anything
  # that would cycle).
  #
  # Rendered via nested attributes on the Recipe form; autosave picks
  # up row edits automatically.
  class ComponentsEditorComponent < ApplicationComponent
    option :recipe
    option :form

    def components
      recipe.components.includes(:componentable).order(:position, :id)
    end

    def pickable_ingredients
      recipe.account.ingredients.kept.order(:category, :name)
    end

    # Recipes that can be safely added as a component without cycling.
    # Uses the model scope that filters out `recipe` itself and every
    # recipe whose tree already reaches back to it.
    def pickable_recipes
      return Recipe.none unless recipe.persisted?

      recipe.account.recipes
        .merge(Recipe.usable_as_component_for(recipe))
        .order(:name)
    end

    def cost_label
      if recipe.cost_cents_cached.present?
        helpers.humanized_money_with_symbol(recipe.cost_cached)
      else
        "—"
      end
    end

    def line_cost_label(component)
      cost_cents = line_cost_cents(component)
      return "—" if cost_cents.nil?

      helpers.humanized_money_with_symbol(Money.new(cost_cents, "MXN"))
    end

    def component_name(component)
      component.componentable&.name.to_s
    end

    def component_type_label(component)
      return nil unless component.componentable.is_a?(Recipe)

      component.componentable.is_saleable? ? nil : I18n.t("recipes.components.internal_tag")
    end

    def compatible_units(component)
      canonical = component.componentable_canonical_unit
      return [ component.unit ] unless canonical

      Recipes::UnitConverter.compatible_units_for(canonical)
    end

    private

    def line_cost_cents(component)
      ing_or_rec = component.componentable
      return nil if ing_or_rec.nil?

      case ing_or_rec
      when Ingredient
        qty = Recipes::UnitConverter.convert(quantity: component.quantity, from: component.unit, to: ing_or_rec.unit)
        (qty * BigDecimal(ing_or_rec.unit_cost_cents.to_s)).to_i
      when Recipe
        child_cost = ing_or_rec.cost_cents_cached.to_i
        return nil if child_cost.zero? || ing_or_rec.yield_quantity.to_d.zero?

        qty = Recipes::UnitConverter.convert(quantity: component.quantity, from: component.unit, to: ing_or_rec.yield_unit)
        (qty / BigDecimal(ing_or_rec.yield_quantity.to_s) * BigDecimal(child_cost.to_s)).to_i
      end
    rescue Recipes::UnitConverter::IncompatibleUnits
      nil
    end
  end
end
