module DevBootstrap
  class Seeder
    def self.call(...)
      new(...).call
    end

    private

    def log(msg)
      puts "  #{msg}"
    end

    def cents(pesos)
      (pesos.to_d * 100).to_i
    end

    def sample_phone
      "662#{rand(100_0000..999_9999)}"
    end

    def sample_email(first, last, domain: "kitchef.mx")
      slug = "#{first}.#{last}#{rand(10..99)}"
             .tr("áéíóúñÁÉÍÓÚÑü", "aeiounAEIOUNu")
             .downcase
             .gsub(/[^a-z0-9.]/, "")
      "#{slug}@#{domain}"
    end
  end
end
