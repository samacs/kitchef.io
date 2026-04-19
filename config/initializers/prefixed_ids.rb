# Hashid-based prefixed IDs (acc_, cli_, ing_, rec_, ord_, pay_, etc.).
#
# The salt only needs to be stable within a given environment — it's used to
# generate reversible, collision-resistant IDs from integer primary keys. The
# dev salt is fine to commit; production reads from ENV and must be long,
# random, and never rotated (existing IDs in URLs / receipts stop decoding).
PrefixedIds.salt = ENV.fetch("PREFIXED_IDS_SALT", "kitchef-dev-salt-replace-in-prod")
PrefixedIds.minimum_length = 8
