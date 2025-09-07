module RouteFinder
  class ItineraryBuilder
    MIN_CONNECTION_TIME = 480.minutes
    MAX_CONNECTION_TIME = 2880.minutes

    def self.call(...)
      new(...).call
    end

    def initialize(blueprint_path:, segments_by_origin:, departure_from:, departure_to:)
      @blueprint_path = blueprint_path
      @segments_by_origin = segments_by_origin
      @departure_from = departure_from.beginning_of_day
      @departure_to = departure_to.end_of_day
      @final_itineraries = []
    end

    def call
      find_initial_segments
      @final_itineraries
    end

    private

    def find_initial_segments
      origin = @blueprint_path.first
      first_destination = @blueprint_path[1]
      
      possible_first_segments = @segments_by_origin[origin] || []
      
      possible_first_segments.each do |segment|
        next unless segment.destination_iata == first_destination
        next unless segment.std.between?(@departure_from, @departure_to)

        find_next_segments([segment], @blueprint_path.drop(2))
      end
    end

    def find_next_segments(current_itinerary, remaining_airports)
      if remaining_airports.empty?
        @final_itineraries << current_itinerary
        return
      end

      last_segment = current_itinerary.last
      next_origin = last_segment.destination_iata
      next_destination = remaining_airports.first

      # Bonus: Prevent visiting the same airport twice in one itinerary.
      # This protects against nonsensical cyclic routes like UUS -> OVB -> UUS -> DME.
      return if current_itinerary.map(&:origin_iata).include?(next_destination)

      possible_next_segments = @segments_by_origin[next_origin] || []

      possible_next_segments.each do |next_segment|
        next unless next_segment.destination_iata == next_destination

        connection_time = (next_segment.std - last_segment.sta)
        if connection_time.between?(MIN_CONNECTION_TIME, MAX_CONNECTION_TIME)
          find_next_segments(current_itinerary + [next_segment], remaining_airports.drop(1))
        end
      end
    end
  end
end
