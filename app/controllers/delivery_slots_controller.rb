class DeliverySlotsController < AuthenticatedController
  def index;   render_stub(title: t("delivery_slots.title"), meta: "delivery_slots#index");   end
  def show;    render_stub(title: t("delivery_slots.title"), meta: "delivery_slots#show");    end
  def new;     render_stub(title: t("delivery_slots.title"), meta: "delivery_slots#new");     end
  def create;  render_stub(title: t("delivery_slots.title"), meta: "delivery_slots#create");  end
  def edit;    render_stub(title: t("delivery_slots.title"), meta: "delivery_slots#edit");    end
  def update;  render_stub(title: t("delivery_slots.title"), meta: "delivery_slots#update");  end
  def destroy; render_stub(title: t("delivery_slots.title"), meta: "delivery_slots#destroy"); end
end
