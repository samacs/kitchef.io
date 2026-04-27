module Demo
  # Persistent amber banner rendered on every operator + storefront
  # page when the account has `demo: true`. Operators should never
  # forget they're inside a demo — losing track of state on a demo
  # session is how a real WhatsApp message gets fired into the void.
  #
  # Renders nothing for non-demo accounts so the production layout
  # stays untouched.
  class BannerComponent < ApplicationComponent
    option :account, optional: true, default: -> { nil }
    option :context, default: -> { :operator }   # :operator | :storefront

    def render?
      effective_account&.demo? == true
    end

    def title
      I18n.t("demo.banner.#{context}.title")
    end

    def body
      I18n.t("demo.banner.#{context}.body")
    end

    private

    def effective_account
      account || helpers.try(:current_account) || Current.try(:account)
    end
  end
end
