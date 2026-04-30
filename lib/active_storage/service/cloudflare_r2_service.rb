require "active_storage/service/s3_service"

module ActiveStorage
  class Service::CloudflareR2Service < Service::S3Service
    def initialize(public_host:, **options)
      @public_host = public_host
      super(**options)
      @upload_options.delete(:acl)
    end

    def public_url(key, **)
      "#{@public_host}/#{key}"
    end
  end
end
