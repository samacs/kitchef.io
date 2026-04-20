module Clients
  # Creates a client scoped to the account. Returns the invalid record on
  # failure so the controller can re-render the form with submitted values.
  class Create < ApplicationCommand
    option :account
    option :params

    def call
      client = account.clients.new(params.to_h)
      if client.save
        success(client)
      else
        Result.new(success: false, object: client, errors: client.errors)
      end
    end
  end
end
