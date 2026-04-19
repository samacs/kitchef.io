require "phonelib"

# Default every phone input to Mexico. When an operator pastes "+52 333 123 4567"
# we accept it; when she writes "333 123 4567" we infer MX. `strict_validation`
# rejects numbers that pass the relaxed pattern but aren't valid MX numbers —
# we'd rather bounce a bad number at form submission than WhatsApp-deep-link to
# a dead phone.
Phonelib.default_country = "MX"
Phonelib.strict_check    = true
