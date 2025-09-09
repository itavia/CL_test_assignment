module RouteFinder
  # This class takes a single blueprint path (e.g., ["UUS", "OVB", "DME"])
  # and recursively searches for all possible real flight itineraries that match it,
  # based on the preloaded segments and connection time constraints.
  class ItineraryBuilder
    MIN_CONNECTION_TIME = 480.minutes
    MAX_CONNECTION_TIME = 2880.minutes

    # @param blueprint_path [Array<String>] A sequence of IATA codes.
    # @param segments_by_origin [Hash{String => Array<Segment>}] A hash of preloaded segments grouped by origin.
    # @param departure_from [Date] The start of the departure window.
    # @param departure_to [Date] The end of the departure window.
    # @return [Array<Array<Segment>>] A list of found itineraries.
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

    # Executes the itinerary building logic.
    # @return [Array<Array<Segment>>] A list of found itineraries.
    def call
      # For a direct flight, the path is [origin, destination]. For a transfer, it's [origin, transfer1, ..., destination].
      # We handle both cases by starting the search with the first leg of the journey.
      find_initial_segments
      @final_itineraries
    end

    private

    # Finds the first valid segment for the blueprint path within the requested departure window.
    def find_initial_segments
      origin = @blueprint_path.first
      # The first destination is the second element in the path.
      first_destination = @blueprint_path[1]
      return unless first_destination # Should not happen with valid blueprint paths

      possible_first_segments = @segments_by_origin[origin] || []

      possible_first_segments.each do |segment|
        next unless segment.destination_iata == first_destination
        next unless segment.std.between?(@departure_from, @departure_to)

        # Start the recursive search for the rest of the itinerary.
        find_next_segments([segment], @blueprint_path.drop(2))
      end
    end

    # Recursively finds the next segments in the itinerary.
    # @param current_itinerary [Array<Segment>] The list of segments found so far.
    # @param remaining_airports [Array<String>] The list of IATA codes yet to be visited.
    def find_next_segments(current_itinerary, remaining_airports)
      # Base case: If there are no more airports to visit, we have a complete itinerary.
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
          # Recursive step: continue building the path with the next segment.
          find_next_segments(current_itinerary + [next_segment], remaining_airports.drop(1))
        end
      end
    end
  end
end
