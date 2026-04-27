module Subscriptions
  # Dismissible upgrade-hint banner. Renders an inline strip with
  # contextual copy + a CTA, plus an "x" button that POSTs to the
  # dismiss endpoint and writes a `Subscriptions::DismissedHint` row
  # for the signed-in account.
  #
  # Pass `redismiss_in:` to make the dismissal expire (e.g.,
  # `30.days` for monthly-resetting hints). Default = permanent
  # dismissal.
  #
  # Usage:
  #   <%= render Subscriptions::HintBanner.new(
  #         hint_key:    "pedidos:approaching_limit",
  #         tone:        :warn,
  #         icon:        :gauge,
  #         title:       t("hints.pedidos.approaching.title", count: 35, limit: 40),
  #         body:        t("hints.pedidos.approaching.body"),
  #         cta_label:   t("hints.pedidos.approaching.cta"),
  #         cta_path:    helpers.subscription_path
  #       ) %>
  class HintBanner < ApplicationComponent
    option :hint_key
    option :title
    option :body,         optional: true, default: -> { nil }
    option :tone,         default: -> { :info }
    option :icon,         optional: true, default: -> { :info }
    option :cta_label,    optional: true, default: -> { nil }
    option :cta_path,     optional: true, default: -> { nil }
    option :redismiss_in, optional: true, default: -> { nil }
    option :account,      optional: true, default: -> { nil }

    TONE_CLASSES = {
      info: "border-line bg-bg-2 text-ink-2",
      warn: "border-warn/40 bg-[color-mix(in_oklab,var(--color-warn)_8%,var(--color-surface))] text-warn-ink",
      pro:  "border-accent/30 bg-accent-soft text-accent"
    }.freeze

    def render?
      return false if effective_account.nil?
      !dismissed?
    end

    def container_classes
      "flex flex-wrap items-start gap-3 rounded-card-sm border px-4 py-3 #{TONE_CLASSES.fetch(tone, TONE_CLASSES[:info])}"
    end

    def dismiss_path
      helpers.hint_dismissal_subscription_path(hint_key: hint_key)
    end

    def redismiss_at_param
      return nil unless redismiss_in
      (Time.current + redismiss_in).iso8601
    end

    private

    def effective_account
      account || helpers.try(:current_account) || Current.try(:account)
    end

    def dismissed?
      Subscriptions::DismissedHint.dismissed?(account: effective_account, hint_key: hint_key.to_s)
    end
  end
end
