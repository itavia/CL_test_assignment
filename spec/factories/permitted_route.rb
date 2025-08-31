# frozen_string_literal: true

FactoryBot.define do
  factory :permitted_route do
    id { SecureRandom.uuid }
    carrier { Faker::Company.name }
    origin_iata { Faker::Airport.code }
    destination_iata { Faker::Airport.code }
    direct { true }
    transfer_iata_codes { [] }
  end
end
