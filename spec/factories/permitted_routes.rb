FactoryBot.define do
  factory :permitted_route do
    carrier { "S7" }
    origin_iata { "UUS" }
    destination_iata { "DME" }
    direct { true }
    transfer_iata_codes { [] }
  end
end
