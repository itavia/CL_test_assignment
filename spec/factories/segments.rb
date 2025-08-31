FactoryBot.define do
  factory :segment do
    airline { "Northtrop" }
    segment_number { "LH1128" }
    origin_iata { "FRO" }
    destination_iata { "SHD" }
    std { Time.new(2025, 8, 31, 5, 50) }
    sta { Time.new(2025, 8, 31,  13, 45) }
  end
end
