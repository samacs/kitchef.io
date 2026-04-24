module HasRfc
  extend ActiveSupport::Concern

  # RFC (Registro Federal de Contribuyentes) — Mexican tax ID.
  #
  # Format (SAT-canonical):
  #   - Persona moral (company):    3 letters + 6 digits (YYMMDD) + 3 alphanumeric = 12 chars
  #   - Persona física (individual): 4 letters + 6 digits (YYMMDD) + 3 alphanumeric = 13 chars
  #   - Letters may include Ñ and &
  #   - Homoclave (trailing 3 chars) can contain digits + letters
  #
  # Always optional. Operators without invoicing needs don't collect it;
  # those who do should be able to paste the value as printed on the
  # SAT card or a previous invoice.
  #
  # We normalize to uppercase + strip whitespace/dashes before validating.
  # Validation runs only when `rfc` is present — never required.
  RFC_FORMAT = /\A[A-ZÑ&]{3,4}\d{6}[A-Z\d]{3}\z/

  included do
    before_validation :normalize_rfc
    validates :rfc,
      format: { with: RFC_FORMAT, message: :invalid_rfc },
      length: { in: 12..13 },
      allow_blank: true
  end

  private

  def normalize_rfc
    return if rfc.blank?
    self.rfc = rfc.to_s.upcase.gsub(/[\s\-]/, "")
  end
end
