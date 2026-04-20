class RecipesController < AuthenticatedController
  def index;   render_stub(title: t("recipes.title"), meta: "recipes#index");   end
  def show;    render_stub(title: t("recipes.title"), meta: "recipes#show");    end
  def new;     render_stub(title: t("recipes.title"), meta: "recipes#new");     end
  def create;  render_stub(title: t("recipes.title"), meta: "recipes#create");  end
  def edit;    render_stub(title: t("recipes.title"), meta: "recipes#edit");    end
  def update;  render_stub(title: t("recipes.title"), meta: "recipes#update");  end
  def destroy; render_stub(title: t("recipes.title"), meta: "recipes#destroy"); end
end
