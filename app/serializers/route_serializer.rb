# This class is responsible for formatting the found itineraries into the
# final JSON structure required by the API response.
class RouteSerializer
  # @param itineraries [Array<Array<Segment>>] A list of itineraries to format.
  # @return [Array<Hash>] A list of formatted itineraries suitable for JSON rendering.
  def self.render(itineraries)
    itineraries.map do |itinerary|
      format_itinerary(itinerary)
    end
  end

  # Formats a single itinerary (an array of segments) into a hash.
  # @param itinerary [Array<Segment>] The itinerary to format.
  # @return [Hash] The formatted itinerary.
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

  # Formats a single segment object into a hash.
  # @param segment [Segment] The segment to format.
  # @return [Hash] The formatted segment.
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
