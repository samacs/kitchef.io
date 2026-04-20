class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  layout "marketing"

  def new;    render_stub(title: t("registrations.title"), meta: "registrations#new");    end
  def create; render_stub(title: t("registrations.title"), meta: "registrations#create"); end
end
