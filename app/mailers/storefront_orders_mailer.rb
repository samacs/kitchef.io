class StorefrontOrdersMailer < ApplicationMailer
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
    # Email CTA lands the customer on the order page — the `?t=…` signed
    # token is what exposes the review/confirm block. The direct
    # post-submit redirect omits the token, so only a customer who opened
    # this email sees the Confirm button. Token rotates with
    # `secret_key_base` and expires after 7 days.
    @review_url = storefront_order_url(
      slug: @account.slug,
      id:   @order.to_param,
      t:    @order.review_token,
      host: @host
    )

    mail(
      to:       @client.email,
      reply_to: reply_to_for(@account),
      from:     from_for(@kitchen_name),
      subject:  t(".subject", kitchen_name: @kitchen_name)
    )
  end

  private

  # Display name on the From: header — "Cocina de Elena <no-reply@kitchef.mx>"
  # reads right in the customer's inbox list without handing kitchens the
  # ability to spoof an arbitrary address. Only the display name is
  # kitchen-controlled; the underlying address stays platform-owned.
  def from_for(kitchen_name)
    address = Mail::Address.new(ApplicationMailer::PLATFORM_FROM)
    address.display_name = kitchen_name.to_s.presence
    address.format
  end

  # When the customer hits reply, the response should land with the kitchen
  # owner, not in Kitchef's no-reply inbox. Use the owner's email address
  # (users.email_address) — it's the one the operator signed in with and
  # checks by definition.
  def reply_to_for(account)
    account.owner&.email_address.presence
  end

  def build_whatsapp_link
    phone = @profile.whatsapp.presence || @profile.phone.presence
    return nil if phone.blank?

    normalized = Phone::NormalizeMx.call(raw: phone)
    return nil if normalized.blank?

    # The message bundles a deep-link back to the operator's kanban so
    # when the operator opens the customer's WhatsApp message, one tap
    # takes her straight to the right pedido card (target_highlight
    # flashes it in place).
    kanban_link = orders_url(host: @host, anchor: "order_#{@order.id}")
    message = t("storefront_orders_mailer.placed.whatsapp_message",
                kitchen_name: @kitchen_name,
                prefix_id:    @order.to_param,
                link:         kanban_link)
    "https://wa.me/#{normalized.sub(/\A\+/, '')}?text=#{ERB::Util.url_encode(message)}"
  end
end
