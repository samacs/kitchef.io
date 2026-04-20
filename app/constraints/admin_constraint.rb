class AdminConstraint < UserConstraint
  def authorized? = super && user.admin?
end
