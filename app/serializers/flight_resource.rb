class FlightResource < ApplicationResource
  attributes :origin_iata, :destination_iata, :departure_time, :arrival_time, :segments

  many :segments
end
