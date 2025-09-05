FactoryBot.define do
  factory :segment do
    airline { "S" }
    segment_number { generate(:segment_number) }
    origin_iata { "UUS" }
    destination_iata { "DME" }
    std { 1.hour.from_now }
    sta { 5.hours.from_now }
  end
end
