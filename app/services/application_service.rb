class ApplicationService
  extend Dry::Initializer

  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError, "#{self.class} must implement #call"
  end
end
