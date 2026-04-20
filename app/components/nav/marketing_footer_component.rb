module Nav
  # Marketing footer — DESIGN.md + landing prototype lines 776-809.
  # Four-column grid on desktop, stacks on mobile.
  class MarketingFooterComponent < ApplicationComponent
    def year = Date.current.year

    def columns
      [
        {
          title: t("marketing.footer.product.title"),
          links: [
            { label: t("marketing.footer.product.orders"),     href: how_it_works_path },
            { label: t("marketing.footer.product.payments"),   href: how_it_works_path },
            { label: t("marketing.footer.product.production"), href: how_it_works_path },
            { label: t("marketing.footer.product.reports"),    href: how_it_works_path }
          ]
        },
        {
          title: t("marketing.footer.company.title"),
          links: [
            { label: t("marketing.footer.company.about"),     href: helpers.root_path },
            { label: t("marketing.footer.company.blog"),      href: helpers.root_path },
            { label: t("marketing.footer.company.customers"), href: faq_path },
            { label: t("marketing.footer.company.contact"),   href: helpers.root_path }
          ]
        },
        {
          title: t("marketing.footer.legal.title"),
          links: [
            { label: t("marketing.footer.legal.terms"),   href: legal_path(doc: "terms") },
            { label: t("marketing.footer.legal.privacy"), href: legal_path(doc: "privacy") },
            { label: t("marketing.footer.legal.notice"),  href: legal_path(doc: "privacy") }
          ]
        }
      ]
    end

    private

    def how_it_works_path = helpers.how_it_works_path
    def faq_path          = helpers.faq_path
    def legal_path(**opts) = helpers.legal_path(**opts)
  end
end
