module Reports
  # Inline preset picker. Renders the five named presets as segmented
  # buttons; the active one carries the accent. A `?range=custom` mode is
  # supported via the explicit `?from=&to=` query params, in which case no
  # preset is highlighted and the view shows the resolved window label.
  class RangePickerComponent < ApplicationComponent
    PRESETS = %i[this_week last_week this_month last_month last_30_days].freeze

    option :active_preset, optional: true
    option :base_path

    def presets
      PRESETS
    end

    def active?(preset)
      active_preset.to_s == preset.to_s
    end
  end
end
