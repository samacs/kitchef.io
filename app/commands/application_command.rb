class ApplicationCommand
  extend Dry::Initializer

  Result = Data.define(:success, :object, :errors) do
    def success? = success
    def failure? = !success
  end

  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  private

  def success(object) = Result.new(success: true, object:, errors: nil)
  def failure(errors) = Result.new(success: false, object: nil, errors:)
end
