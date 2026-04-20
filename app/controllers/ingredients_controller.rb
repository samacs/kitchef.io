class IngredientsController < AuthenticatedController
  def index;   render_stub(title: t("ingredients.title"), meta: "ingredients#index");   end
  def show;    render_stub(title: t("ingredients.title"), meta: "ingredients#show");    end
  def new;     render_stub(title: t("ingredients.title"), meta: "ingredients#new");     end
  def create;  render_stub(title: t("ingredients.title"), meta: "ingredients#create");  end
  def edit;    render_stub(title: t("ingredients.title"), meta: "ingredients#edit");    end
  def update;  render_stub(title: t("ingredients.title"), meta: "ingredients#update");  end
  def destroy; render_stub(title: t("ingredients.title"), meta: "ingredients#destroy"); end
end
