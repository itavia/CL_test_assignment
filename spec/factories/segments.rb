FactoryBot.define do
  factory :segment do
    airline { "S7" }
    sequence(:segment_number) { |n| "SEG#{n}" }
    origin_iata { "UUS" }
    destination_iata { "DME" }
    std { Time.utc(2024, 1, 1, 8, 0) }
    sta { Time.utc(2024, 1, 1, 12, 0) }
  end
end
