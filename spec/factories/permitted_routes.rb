FactoryBot.define do
  factory :permitted_route do
    carrier { "Northtrop" }
    origin_iata { "FRO" }
    destination_iata { "AUR" }
    direct { true }
    transfer_iata_codes { [] }
    
    trait :with_transfers do
      transfer_iata_codes { ["SHD", "SKY", "SHDICY", "SKYICYSUN"] }
    end
  end
end
