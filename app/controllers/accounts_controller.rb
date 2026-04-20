class AccountsController < AuthenticatedController
  def show;   render_stub(title: t("account.title"), meta: "account#show");   end
  def edit;   render_stub(title: t("account.title"), meta: "account#edit");   end
  def update; render_stub(title: t("account.title"), meta: "account#update"); end
end
