class StorefrontOrdersMailer < ApplicationMailer
  default from: "pedidos@kitchef.mx"

  # Fires when a customer submits a storefront order AND left an email.
  # Sent from Storefronts::PlaceOrder via `.with(order:).placed.deliver_later`
  # so the mailer args serialize cleanly for Sidekiq.
  def placed
    @order    = params[:order]
    @account  = @order.account
    @client   = @order.client
    @profile  = @account.public_profile

    return if @account.discarded_at.present?
    return if @client&.email.blank?

    @kitchen_name = @account.name
    @whatsapp_link = build_whatsapp_link
    @host          = Rails.application.config.action_mailer.default_url_options.fetch(:host, "kitchef.mx")
    @status_url    = storefront_order_url(slug: @account.slug, id: @order.to_param, host: @host)
    # Self-confirm CTA appears only when the customer left NO phone —
    # the phone path is routed through WhatsApp instead (once that
    # channel is live). No phone = no WhatsApp = we give the customer
    # a one-tap confirm link so the kitchen isn't stuck waiting.
    @self_confirm_url = if @client&.phone_normalized.blank?
      confirm_storefront_order_url(slug: @account.slug, id: @order.to_param, host: @host)
    end

    mail(
      to:      @client.email,
      subject: t(".subject", kitchen_name: @kitchen_name)
    )
  end

  private

  def build_whatsapp_link
    phone = @profile.whatsapp.presence || @profile.phone.presence
    return nil if phone.blank?

    normalized = Phone::NormalizeMx.call(raw: phone)
    return nil if normalized.blank?

    message = t("storefront_orders_mailer.placed.whatsapp_message",
                kitchen_name: @kitchen_name,
                prefix_id:    @order.to_param)
    "https://wa.me/#{normalized.sub(/\A\+/, '')}?text=#{ERB::Util.url_encode(message)}"
  end
end
