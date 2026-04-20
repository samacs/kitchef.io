module Clients
  class Update < ApplicationCommand
    option :client
    option :params

    def call
      if client.update(params.to_h)
        success(client)
      else
        Result.new(success: false, object: client, errors: client.errors)
      end
    end
  end
end
