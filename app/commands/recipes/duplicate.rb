module Recipes
  # Clones an existing recipe (saleable or internal) into a fresh draft.
  # Copies the components and the option groups but NOT photos, audit
  # history, or position. Always lands `is_published: false` so the
  # operator reviews + tweaks before re-exposing on the storefront.
  #
  # Usage:
  #   result = Recipes::Duplicate.call(recipe: source)
  #   result.success? # → true
  #   result.object   # → the freshly-saved Recipe
  class Duplicate < ApplicationCommand
    option :recipe
    option :name, optional: true  # override default "(copia)" suffix when set

    def call
      copy = build_copy
      copy.save!

      duplicate_components_into(copy)
      duplicate_option_groups_into(copy)

      success(copy.reload)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, object: e.record, errors: e.record.errors)
    end

    private

    def build_copy
      account = recipe.account
      account.recipes.new(
        name:                  duplicated_name,
        description:           recipe.description,
        sale_price_cents:      recipe.sale_price_cents,
        category_id:           recipe.category_id,
        is_saleable:           recipe.is_saleable?,
        is_published:          false,
        yield_quantity:        recipe.yield_quantity,
        yield_unit:            recipe.yield_unit,
        target_margin_percent: recipe.target_margin_percent,
        packaging_cents:       recipe.packaging_cents,
        lead_time_hours:       recipe.lead_time_hours
      )
    end

    def duplicated_name
      return name.to_s.strip if name.present?

      base = recipe.name.to_s
      "#{base} #{I18n.t("recipes.duplicate.copy_suffix")}".strip
    end

    def duplicate_components_into(copy)
      recipe.components.find_each do |source|
        copy.components.create!(
          componentable_type: source.componentable_type,
          componentable_id:   source.componentable_id,
          quantity:           source.quantity,
          unit:               source.unit,
          notes:              source.notes,
          is_removable:       source.is_removable,
          position:           source.position
        )
      end
    end

    def duplicate_option_groups_into(copy)
      recipe.option_groups.kept.find_each do |group|
        new_group = copy.option_groups.create!(
          account_id: group.account_id,
          label:      group.label,
          sub:        group.sub,
          kind:       group.kind,
          required:   group.required,
          position:   group.position,
          max_length: group.max_length
        )

        group.options.kept.find_each do |option|
          new_group.options.create!(
            label:             option.label,
            sub:               option.sub,
            price_delta_cents: option.price_delta_cents,
            is_default:        option.is_default,
            color_hex:         option.color_hex,
            position:          option.position
          )
        end
      end
    end
  end
end
