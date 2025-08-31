# frozen_string_literal: true

FactoryBot.define do
  factory :segment do
    id { SecureRandom.uuid }
    airline { Faker::Company.name }
    sequence(:segment_number)
    origin_iata { Faker::Airport.code }
    destination_iata { Faker::Airport.code }
    std { Faker::Time.between(from: DateTime.now - 1, to: DateTime.now) }
    sta { Faker::Time.between(from: DateTime.now + 1, to: DateTime.now + 2) }
  end
end
