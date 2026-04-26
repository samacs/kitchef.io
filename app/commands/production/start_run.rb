module Production
  # Creates a ProductionRun from the operator's "I cooked X today" form
  # and immediately deducts the ingredients via DepleteIngredients.
  # Goes from `planned → in_progress` in the same call — the operator
  # is filling out the form because she's actively cooking, not
  # planning. Future "schedule for tomorrow" UX would skip the AASM
  # `start!` and leave the run in `planned`.
  class StartRun < ApplicationCommand
    option :account
    option :params

    def call
      attrs = normalized_params

      run = account.production_runs.new(attrs)
      run.actual_quantity = attrs[:planned_quantity] if attrs[:planned_quantity].present?

      ActiveRecord::Base.transaction do
        run.save!
        Production::DepleteIngredients.call(run: run)
        run.start!
      end

      success(run)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, object: e.record, errors: e.record.errors)
    end

    private

    def normalized_params
      attrs = params.to_h.deep_symbolize_keys
      window_days = account.inventory_settings.default_run_window_days.to_i

      cooked_on = parse_date(attrs[:cooked_on]) || Date.current
      attrs[:cooked_on]       = cooked_on
      attrs[:available_from]  = parse_date(attrs[:available_from])  || cooked_on
      attrs[:available_until] = parse_date(attrs[:available_until]) || (cooked_on + window_days.days)

      # Storefront-style prefixed_id fallback so the form can post
      # `rec_xxx` instead of the numeric id.
      if attrs[:recipe_id].to_s.start_with?("rec_")
        recipe = account.recipes.kept.saleable.find_by_prefix_id(attrs[:recipe_id].to_s)
        attrs[:recipe_id] = recipe&.id
      end

      attrs[:planned_quantity] = attrs[:planned_quantity].to_d if attrs[:planned_quantity].present?
      attrs
    end

    def parse_date(raw)
      return nil if raw.blank?
      return raw if raw.is_a?(Date)
      Date.iso8601(raw.to_s)
    rescue Date::Error
      nil
    end
  end
end
