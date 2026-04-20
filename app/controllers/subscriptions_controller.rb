class SubscriptionsController < AuthenticatedController
  def show;    render_stub(title: t("subscription.title"), meta: "subscription#show");    end
  def new;     render_stub(title: t("subscription.title"), meta: "subscription#new");     end
  def create;  render_stub(title: t("subscription.title"), meta: "subscription#create");  end
  def destroy; render_stub(title: t("subscription.title"), meta: "subscription#destroy"); end
end
