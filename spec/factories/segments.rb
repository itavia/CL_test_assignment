FactoryBot.define do
  factory :segment do
    airline { "S7" }
    sequence(:segment_number) { |n| "123#{n}" }
    origin_iata { "UUS" }
    destination_iata { "DME" }
    std { Time.now }
    sta { Time.now + 4.hours }
  end
end
