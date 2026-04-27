module Demo
  # Single helper every demo-aware service / job / mailer asks: "is
  # this thing on a demo account?". Walks a few common shapes so
  # callers don't need to remember whether the record is an Order,
  # an Account, a Client, or whatever — they just hand it over and
  # we figure it out.
  #
  # Centralizing the predicate here means a future refactor (e.g.
  # demo at the User level) is a one-file change.
  module_function

  def skip?(record)
    account_for(record)&.demo? == true
  end

  def account_for(record)
    return nil if record.nil?
    return record if record.is_a?(Account)
    return record.account if record.respond_to?(:account)
    return record.storefront if record.respond_to?(:storefront)
    nil
  end
end
