module JsonLdHelper
  def json_ld_tag(data)
    tag.script(data.to_json.html_safe, type: "application/ld+json")
  end

  # -- Site-wide schemas (marketing pages) --------------------------------

  def json_ld_website
    json_ld_tag({
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "Kitchef",
      "url" => root_url,
      "description" => t("meta.default_description"),
      "inLanguage" => "es-MX"
    })
  end

  def json_ld_organization
    json_ld_tag({
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "Kitchef",
      "url" => root_url,
      "logo" => image_url("logo.svg"),
      "description" => t("meta.default_description"),
      "foundingDate" => "2026",
      "contactPoint" => {
        "@type" => "ContactPoint",
        "email" => "hola@kitchef.mx",
        "contactType" => "customer service",
        "availableLanguage" => "es"
      },
      "areaServed" => {
        "@type" => "Country",
        "name" => "México"
      }
    })
  end

  def json_ld_software_application
    json_ld_tag({
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "name" => "Kitchef",
      "url" => root_url,
      "applicationCategory" => "BusinessApplication",
      "operatingSystem" => "Web",
      "description" => t("meta.default_description"),
      "offers" => [
        {
          "@type" => "Offer",
          "name" => "Gratis",
          "price" => "0",
          "priceCurrency" => "MXN",
          "description" => t("meta.offers.free")
        },
        {
          "@type" => "Offer",
          "name" => "Pro · Mensual",
          "price" => "199",
          "priceCurrency" => "MXN",
          "billingIncrement" => "P1M",
          "description" => t("meta.offers.pro")
        },
        {
          "@type" => "Offer",
          "name" => "Pro · Anual",
          "price" => "1990",
          "priceCurrency" => "MXN",
          "billingIncrement" => "P1Y",
          "description" => t("meta.offers.pro")
        }
      ],
      "featureList" => [
        "Pedidos y kanban",
        "Menú público con tu marca",
        "Recetario con costeo automático",
        "Calendario de producción",
        "Reportes de finanzas e ingeniería de menú",
        "Lista de compras semanal",
        "Directorio de clientes"
      ]
    })
  end

  # -- Storefront schemas (kitchen pages) ---------------------------------

  def json_ld_food_establishment(account)
    sf_url = storefront_url(slug: account.slug)
    profile = account.public_profile

    data = {
      "@context" => "https://schema.org",
      "@type" => "FoodEstablishment",
      "@id" => sf_url,
      "name" => account.name,
      "url" => sf_url,
      "currenciesAccepted" => "MXN",
      "paymentAccepted" => t("meta.storefront.payment_accepted"),
      "servesCuisine" => t("meta.storefront.serves_cuisine")
    }

    data["description"] = profile.description if profile.description.present?
    data["telephone"] = profile.phone if profile.phone.present?

    if account.logo.attached?
      data["logo"] = url_for(account.logo.variant(:thumb))
      data["image"] = url_for(account.logo.variant(:card))
    end

    if account.cover_photo.attached?
      data["image"] = url_for(account.cover_photo)
    end

    if account.street_address.present? && profile.show_pickup_address
      data["address"] = {
        "@type" => "PostalAddress",
        "streetAddress" => account.street_address,
        "addressLocality" => profile.city,
        "addressRegion" => profile.colonia,
        "addressCountry" => "MX"
      }.compact
    elsif profile.city.present?
      data["address"] = {
        "@type" => "PostalAddress",
        "addressLocality" => profile.city,
        "addressCountry" => "MX"
      }
    end

    if account.latitude.present? && account.longitude.present?
      data["geo"] = {
        "@type" => "GeoCoordinates",
        "latitude" => account.latitude.to_f,
        "longitude" => account.longitude.to_f
      }
    end

    if profile.city.present?
      data["areaServed"] = {
        "@type" => "City",
        "name" => profile.city
      }
    end

    data["priceRange"] = price_range_for(account)

    if profile.instagram.present?
      data["sameAs"] = [ "https://instagram.com/#{profile.instagram.delete("@")}" ]
    end

    fulfillment = []
    fulfillment << "pickup" if profile.offers_pickup?
    fulfillment << "delivery" if profile.offers_delivery?
    if fulfillment.any?
      data["potentialAction"] = {
        "@type" => "OrderAction",
        "target" => {
          "@type" => "EntryPoint",
          "urlTemplate" => sf_url,
          "actionPlatform" => [
            "https://schema.org/DesktopWebPlatform",
            "https://schema.org/MobileWebPlatform"
          ]
        },
        "deliveryMethod" => fulfillment.map { |f|
          f == "delivery" ? "https://schema.org/HomeDelivery" : "https://schema.org/OnSitePickup"
        }
      }
    end

    json_ld_tag(data)
  end

  def json_ld_menu(account, recipes_by_category)
    sf_url = storefront_url(slug: account.slug)

    sections = recipes_by_category.map do |category, recipes|
      {
        "@type" => "MenuSection",
        "name" => category&.name || t("meta.storefront.uncategorized"),
        "hasMenuItem" => recipes.select(&:is_published).map { |recipe|
          menu_item_data(recipe, account)
        }
      }
    end

    json_ld_tag({
      "@context" => "https://schema.org",
      "@type" => "Menu",
      "name" => t("meta.storefront.menu_name", kitchen: account.name),
      "url" => sf_url,
      "hasMenuSection" => sections
    })
  end

  # -- Dish detail schemas ------------------------------------------------

  def json_ld_menu_item(recipe, account)
    data = menu_item_data(recipe, account)
    data["@context"] = "https://schema.org"

    if recipe.photos.attached?
      data["image"] = recipe.ordered_photos.first(3).map { |photo|
        url_for(photo.variant(resize_to_limit: [ 1200, 800 ]))
      }
    end

    if recipe.description.present?
      data["description"] = recipe.description
    end

    json_ld_tag(data)
  end

  def json_ld_product(recipe, account)
    recipe_url = storefront_recipe_url(slug: account.slug, recipe_slug: recipe.slug)
    sf_url = storefront_url(slug: account.slug)

    data = {
      "@context" => "https://schema.org",
      "@type" => "Product",
      "name" => recipe.name,
      "url" => recipe_url,
      "category" => recipe.category&.name,
      "brand" => {
        "@type" => "Brand",
        "name" => account.name
      },
      "offers" => {
        "@type" => "Offer",
        "price" => (recipe.sale_price_cents / 100.0).to_s,
        "priceCurrency" => "MXN",
        "availability" => "https://schema.org/InStock",
        "seller" => {
          "@type" => "FoodEstablishment",
          "name" => account.name,
          "url" => sf_url
        }
      }
    }.compact

    if recipe.photos.attached?
      data["image"] = recipe.ordered_photos.first(3).map { |photo|
        url_for(photo.variant(resize_to_limit: [ 1200, 800 ]))
      }
    end

    data["description"] = recipe.description if recipe.description.present?

    json_ld_tag(data)
  end

  # -- Reusable schemas ---------------------------------------------------

  def json_ld_breadcrumb_list(items)
    json_ld_tag({
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items.each_with_index.map do |item, index|
        {
          "@type" => "ListItem",
          "position" => index + 1,
          "name" => item[:name],
          "item" => item[:url]
        }
      end
    })
  end

  def json_ld_faq_page(faqs)
    json_ld_tag({
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => faqs.map do |faq|
        {
          "@type" => "Question",
          "name" => faq[:q],
          "acceptedAnswer" => {
            "@type" => "Answer",
            "text" => faq[:a]
          }
        }
      end
    })
  end

  private

  def menu_item_data(recipe, account)
    data = {
      "@type" => "MenuItem",
      "name" => recipe.name,
      "url" => storefront_recipe_url(slug: account.slug, recipe_slug: recipe.slug),
      "offers" => {
        "@type" => "Offer",
        "price" => (recipe.sale_price_cents / 100.0).to_s,
        "priceCurrency" => "MXN",
        "availability" => "https://schema.org/InStock"
      }
    }

    data["description"] = recipe.description if recipe.description.present?

    if recipe.photos.attached?
      data["image"] = url_for(recipe.ordered_photos.first.variant(resize_to_limit: [ 800, 600 ]))
    end

    data
  end

  def price_range_for(account)
    prices = account.recipes.kept.published.where("sale_price_cents > 0").pluck(:sale_price_cents)
    return nil if prices.empty?

    min = (prices.min / 100.0).ceil
    max = (prices.max / 100.0).ceil
    min == max ? "$#{min} MXN" : "$#{min} – $#{max} MXN"
  end
end
