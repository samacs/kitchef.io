module HasPrefixedId
  extend ActiveSupport::Concern

  # Wraps the prefixed_ids gem with the additional behavior we always want:
  # expose the prefixed id as `to_param`, add a `.find_by_prefix_id` finder,
  # and register the prefix on the model for reverse-lookup helpers. Include
  # as `include HasPrefixedId.new(prefix: "acc")`.
  def self.new(prefix:)
    Module.new do
      extend ActiveSupport::Concern

      included do
        has_prefix_id prefix
      end

      class_methods do
        # Resolve a prefixed id (e.g. "acc_abc123xyz") to a record. Returns
        # nil when the id doesn't decode or doesn't match the model prefix.
        def find_by_prefix_id(id)
          find_by(id: PrefixedIds.find(id)&.id)
        rescue PrefixedIds::Error, NoMethodError
          nil
        end
      end
    end
  end
end
