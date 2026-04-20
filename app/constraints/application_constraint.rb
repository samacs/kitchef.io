class ApplicationConstraint
  attr_reader :request

  def initialize(request) = @request = request

  class << self
    def matches?(request) = new(request).authorized?
  end

  def authorized? = raise NotImplementedError
end
