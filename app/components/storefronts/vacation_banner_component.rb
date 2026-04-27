module Storefronts
  # Full-width banner that surfaces on every storefront page when the
  # kitchen is on vacation (`Schedule#on_vacation?`). Renders nothing
  # for kitchens that are open. The operator's optional
  # `vacation_message` overrides the default "Volvemos el [fecha]"
  # copy so she can say "Cerramos por mudanza" / "Embarazo" / etc.
  #
  # Layout-mounted so we don't have to remember to add it to every
  # storefront template.
  class VacationBannerComponent < ApplicationComponent
    option :storefront

    def render?
      schedule&.on_vacation? == true
    end

    def schedule
      @schedule ||= storefront.schedule
    end

    def heading
      helpers.t("storefronts.vacation_banner.heading")
    end

    def body
      schedule.vacation_message.presence || default_body
    end

    # Uses `helpers.t` (not bare I18n.t) so the `_html` suffix is
    # honored — TranslationHelper auto-escapes interpolations and
    # marks the result html_safe so the static `<strong>` in the
    # locale renders as HTML, not as text.
    def default_body
      helpers.t(
        "storefronts.vacation_banner.default_body_html",
        date: helpers.l(schedule.vacation_resumes_on, format: :long)
      )
    end
  end
end
