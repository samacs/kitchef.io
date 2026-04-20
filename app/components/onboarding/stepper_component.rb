module Onboarding
  # Linear progress indicator for the onboarding wizard. Each step is a
  # dot + label; the active step is filled and framed, earlier steps get a
  # check mark, later steps are muted. Renders horizontally on tablet+
  # and stacks to a compact numeric summary on mobile (width-based — no
  # viewport JS needed).
  class StepperComponent < ApplicationComponent
    STEPS = %i[kitchen description logo cover done].freeze

    option :current

    def dot_classes(state)
      base = "inline-flex items-center justify-center shrink-0 w-[26px] h-[26px] rounded-full text-[12px] font-mono font-medium"
      case state
      when :done     then "#{base} bg-accent text-bg"
      when :current  then "#{base} bg-accent-soft text-accent ring-2 ring-accent/40 ring-offset-2 ring-offset-bg"
      else                "#{base} bg-bg-2 text-muted border border-line"
      end
    end

    def label_classes(state)
      base = "text-[12.5px] font-medium truncate transition-colors"
      case state
      when :done     then "#{base} text-ink-2"
      when :current  then "#{base} text-ink"
      else                "#{base} text-muted"
      end
    end

    # Fractional widths match STEPS.size (5): 1/5 .. full. Using static
    # class names so Tailwind v4's JIT can discover them at build time —
    # no inline styles per CLAUDE.md view-layer rules.
    PROGRESS_CLASSES = %w[w-1/5 w-2/5 w-3/5 w-4/5 w-full].freeze

    def progress_class
      PROGRESS_CLASSES[current_number - 1] || PROGRESS_CLASSES.first
    end

    def steps
      STEPS.each_with_index.map do |key, idx|
        step_number = idx + 1
        { key: key, number: step_number, state: state_for(step_number), label: I18n.t("onboarding.stepper.#{key}") }
      end
    end

    def current_label
      steps.find { |s| s[:state] == :current }&.fetch(:label) || steps.first[:label]
    end

    def total
      STEPS.size
    end

    def current_number
      current.clamp(1, total)
    end

    private

    def state_for(step_number)
      if step_number < current_number
        :done
      elsif step_number == current_number
        :current
      else
        :upcoming
      end
    end
  end
end
