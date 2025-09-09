# This service is the main entry point for the flight search logic.
# It orchestrates the process of finding flight itineraries based on
# permitted routes and available flight segments.
class RouteFinderService
  # Entry point for the service.
  # @param params [Hash] The search parameters from the controller.
  # @option params [String] :carrier The airline carrier code.
  # @option params [String] :origin_iata The origin airport IATA code.
  # @option params [String] :destination_iata The destination airport IATA code.
  # @option params [Date] :departure_from The start of the departure window.
  # @option params [Date] :departure_to The end of the departure window.
  # @return [Array<Array<Segment>>] A list of found itineraries, where each itinerary is an array of Segment objects.
  def self.call(params)
    new(params).call
  end

  # Initializes the service with the search parameters.
  # @param params [Hash] The search parameters.
  def initialize(params)
    @carrier = params[:carrier]
    @origin_iata = params[:origin_iata]
    @destination_iata = params[:destination_iata]
    @departure_from = params[:departure_from]
    @departure_to = params[:departure_to]
  end

  # Executes the main logic of the service.
  # @return [Array<Array<Segment>>] A list of found itineraries.
  def call
    # 1. Find the rule for the requested route.
    permitted_route = PermittedRoute.find_by(
      carrier: @carrier,
      origin_iata: @origin_iata,
      destination_iata: @destination_iata
    )

    return [] unless permitted_route

    # 2. Parse the rule into a list of possible airport sequences (blueprint paths).
    blueprint_paths = RouteFinder::PermittedRouteParser.call(permitted_route)
    return [] if blueprint_paths.empty?

    # 3. Preload all potentially relevant flight segments to avoid N+1 queries.
    preload_segments(blueprint_paths)

    # 4. For each blueprint path, build all possible real itineraries.
    itineraries = blueprint_paths.flat_map do |path|
      RouteFinder::ItineraryBuilder.call(
        blueprint_path: path,
        segments_by_origin: @segments_by_origin,
        departure_from: @departure_from,
        departure_to: @departure_to
      )
    end

    itineraries
  end

  private

  # Preloads all segments that could possibly be part of a valid itinerary.
  # This is the key optimization to prevent N+1 database queries.
  # The segments are grouped by their origin airport for fast lookups.
  # @param blueprint_paths [Array<Array<String>>] The list of possible airport sequences.
  def preload_segments(blueprint_paths)
    all_airports = blueprint_paths.flatten.uniq

    # The date range for segments should be wide enough to accommodate connections.
    # We take the user's departure window and add the max connection time.
    end_date = @departure_to.end_of_day + 48.hours

    segments = Segment.where(
      airline: @carrier,
      origin_iata: all_airports,
      std: @departure_from.beginning_of_day..end_date
    ).to_a

    @segments_by_origin = segments.group_by(&:origin_iata)
  end
end
