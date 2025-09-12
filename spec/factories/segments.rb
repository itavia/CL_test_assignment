FactoryBot.define do
  factory :segment do
    airline { "S7" }
    sequence(:segment_number) { |n| "12#{n.to_s.rjust(2, '0')}" }
    origin_iata { "UUS" }
    destination_iata { "VVO" }
    std { Time.zone.now + 1.day }
    sta { Time.zone.now + 1.day + 2.hours }
  end
end
