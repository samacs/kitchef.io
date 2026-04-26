require "open-uri"
require "fileutils"

module DevBootstrap
  module ImageCache
    CACHE_DIR = Rails.root.join("tmp/recipes")
    EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze

    UNSPLASH = lambda { |photo_id, w: 900|
      "https://images.unsplash.com/#{photo_id}?auto=format&fit=crop&w=#{w}&q=80"
    }

    def self.setup
      FileUtils.mkdir_p(CACHE_DIR)
    end

    def self.find_or_fetch(slug, unsplash_id: nil, url: nil)
      setup

      existing = find_cached(slug)
      return existing if existing

      remote_url = url || (unsplash_id ? UNSPLASH.call(unsplash_id) : nil)
      return nil if remote_url.blank?

      fetch_and_cache(slug, remote_url)
    end

    def self.find_cached(slug)
      EXTENSIONS.each do |ext|
        path = CACHE_DIR.join("#{slug}#{ext}")
        return path if path.exist?
      end
      nil
    end

    def self.fetch_and_cache(slug, url)
      filename = "#{slug}.jpg"
      path = CACHE_DIR.join(filename)
      return path if path.exist?

      URI.open(url, open_timeout: 8, read_timeout: 20) do |remote|
        File.binwrite(path, remote.read)
      end
      path
    rescue StandardError => e
      warn "  ⚠  image fetch failed for #{slug}: #{e.class}: #{e.message}"
      nil
    end

    def self.attach(record, attachment_name, slug:, unsplash_id: nil, url: nil)
      return if record.public_send(attachment_name).attached?

      path = find_or_fetch(slug, unsplash_id: unsplash_id, url: url)
      return if path.nil?

      ext = File.extname(path).delete(".")
      content_type = case ext
                     when "png"  then "image/png"
                     when "webp" then "image/webp"
                     else "image/jpeg"
                     end

      record.public_send(attachment_name).attach(
        io:           File.open(path, "rb"),
        filename:     "#{slug}.#{ext}",
        content_type: content_type
      )
    rescue StandardError => e
      warn "  ⚠  attach failed for #{slug}: #{e.class}: #{e.message}"
    end
  end
end
