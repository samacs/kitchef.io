class UserConstraint < ApplicationConstraint
  attr_reader :user, :cookies

  def initialize(request)
    super
    @cookies = ActionDispatch::Cookies::CookieJar.build(request, request.cookies)
    @user    = find_user
  end

  def authorized? = user.present?

  private

  # Mirrors Authentication#find_session_by_cookie — resolves the session
  # record via the signed `:session_id` cookie set by start_new_session_for.
  def find_user
    session_id = cookies.signed[:session_id]
    return unless session_id

    Session.find_by(id: session_id)&.user
  end
end
