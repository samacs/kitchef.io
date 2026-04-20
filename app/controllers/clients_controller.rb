class ClientsController < AuthenticatedController
  def index;   render_stub(title: t("clients.title"), meta: "clients#index");   end
  def show;    render_stub(title: t("clients.title"), meta: "clients#show");    end
  def new;     render_stub(title: t("clients.title"), meta: "clients#new");     end
  def create;  render_stub(title: t("clients.title"), meta: "clients#create");  end
  def edit;    render_stub(title: t("clients.title"), meta: "clients#edit");    end
  def update;  render_stub(title: t("clients.title"), meta: "clients#update");  end
  def destroy; render_stub(title: t("clients.title"), meta: "clients#destroy"); end
end
