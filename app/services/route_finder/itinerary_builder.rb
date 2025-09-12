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
      find_initial_segments
      @final_itineraries
    end

    private

    # Finds the first valid segment for the blueprint path within the requested departure window.
    def find_initial_segments
      origin = @blueprint_path.first
      first_destination = @blueprint_path[1]
      return unless first_destination

      segments_for_origin = @segments_by_origin[origin] || []
      segments_for_origin.each do |segment|
        next unless initial_segment_valid?(segment, first_destination)

        find_next_segments([segment], @blueprint_path.drop(2))
      end
    end

    # Recursively finds the next segments in the itinerary.
    # @param current_itinerary [Array<Segment>] The list of segments found so far.
    # @param remaining_airports [Array<String>] The list of IATA codes yet to be visited.
    def find_next_segments(current_itinerary, remaining_airports)
      if complete_itinerary?(remaining_airports)
        @final_itineraries << current_itinerary
        return
      end

      last_segment = current_itinerary.last
      next_destination = remaining_airports.first

      return unless non_cyclic_route?(current_itinerary, next_destination)

      possible_next_segments = @segments_by_origin[last_segment.destination_iata] || []
      possible_next_segments.each do |next_segment|
        if valid_next_segment?(last_segment, next_segment, next_destination)
          find_next_segments(current_itinerary + [next_segment], remaining_airports.drop(1))
        end
      end
    end

    # --- Validation Helpers ---

    def initial_segment_valid?(segment, destination)
      segment.destination_iata == destination && segment.std.between?(@departure_from, @departure_to)
    end

    def complete_itinerary?(remaining_airports)
      remaining_airports.empty?
    end

    def valid_next_segment?(last_segment, next_segment, destination)
      next_segment.destination_iata == destination &&
        valid_connection?(last_segment, next_segment)
    end

    def valid_connection?(last_segment, next_segment)
      connection_time = next_segment.std - last_segment.sta
      connection_time.between?(MIN_CONNECTION_TIME, MAX_CONNECTION_TIME)
    end

    # Bonus: Prevent visiting the same airport twice in one itinerary.
    # This protects against nonsensical cyclic routes like UUS -> OVB -> UUS -> DME.
    def non_cyclic_route?(itinerary, next_destination)
      !itinerary.map(&:origin_iata).include?(next_destination)
    end
  end
end