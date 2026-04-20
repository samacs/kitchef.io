class OrdersController < AuthenticatedController
  def index;   render_stub(title: t("orders.title"), meta: "orders#index");   end
  def show;    render_stub(title: t("orders.title"), meta: "orders#show");    end
  def new;     render_stub(title: t("orders.title"), meta: "orders#new");     end
  def create;  render_stub(title: t("orders.title"), meta: "orders#create");  end
  def edit;    render_stub(title: t("orders.title"), meta: "orders#edit");    end
  def update;  render_stub(title: t("orders.title"), meta: "orders#update");  end
  def destroy; render_stub(title: t("orders.title"), meta: "orders#destroy"); end
end
