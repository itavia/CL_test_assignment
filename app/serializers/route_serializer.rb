class RouteSerializer
  def self.render(itineraries)
    itineraries.map do |itinerary|
      format_itinerary(itinerary)
    end
  end

  def self.format_itinerary(itinerary)
    first_segment = itinerary.first
    last_segment = itinerary.last

    {
      origin_iata: first_segment.origin_iata,
      destination_iata: last_segment.destination_iata,
      departure_time: first_segment.std,
      arrival_time: last_segment.sta,
      segments: itinerary.map { |segment| format_segment(segment) }
    }
  end

  def self.format_segment(segment)
    {
      carrier: segment.airline,
      segment_number: segment.segment_number,
      origin_iata: segment.origin_iata,
      destination_iata: segment.destination_iata,
      std: segment.std,
      sta: segment.sta
    }
  end
end
