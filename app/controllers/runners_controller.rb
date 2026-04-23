# Zero-auth per-day delivery list, reachable via a signed token the
# operator shares with her runner via WhatsApp. The token IS the only
# secret — tampering or expiry lands on a branded "ruta expirada" page.
#
# Does NOT inherit from AuthenticatedController: the point of this
# surface is that a teenage nephew with a phone can open it without
# logging in. All state changes happen via AASM guards, so a replayed
# or shared link can't mutate an order that's already delivered.
class RunnersController < ApplicationController
  # Zero-auth by design: the token IS the secret. Skip the authentication
  # concern's default gate via the helper the concern exposes.
  allow_unauthenticated_access
  layout "application"

  helper MapsHelper

  rescue_from Runner::Token::Invalid, with: :render_invalid_token

  before_action :decode_token

  def show
    @orders = orders_for_day.order(:delivery_start_time, :created_at)
  end

  def deliver
    order = orders_for_day.find_by(id: params[:id])
    return redirect_to runner_path(params[:token]), alert: I18n.t("runners.errors.not_found") if order.nil?

    Orders::Transition.call(order: order, event: :deliver)
    redirect_to runner_path(params[:token])
  end

  private

  def decode_token
    @decoded = Runner::Token.decode(params[:token])
    @account = Account.kept.find_by(id: @decoded.account_id)
    raise Runner::Token::Invalid, "account missing" if @account.nil?

    @on = @decoded.date
  end

  def orders_for_day
    @account.orders.kept
      .where(delivery_date: @on, delivery_type: Order.delivery_types[:delivery])
      .where.not(state: "canceled")
      .includes(:client, items: :recipe)
  end

  def render_invalid_token
    render "invalid", status: :gone
  end
end
