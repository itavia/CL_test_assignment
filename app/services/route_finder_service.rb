# This service is the main entry point for the flight search logic.
# It orchestrates the process of finding flight itineraries based on
# permitted routes and available flight segments.
class RouteFinderService
  MAX_CONNECTION_HOURS = 48.hours

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
    max_stops = blueprint_paths.map { |path| path.length - 2 }.max
    max_stops = [0, max_stops].max # Ensure it's not negative for direct flights

    segments_by_origin = preload_segments(blueprint_paths, max_stops)

    # 4. For each blueprint path, build all possible real itineraries.
    itineraries = blueprint_paths.flat_map do |path|
      RouteFinder::ItineraryBuilder.call(
        blueprint_path: path,
        segments_by_origin: segments_by_origin,
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
  # @param max_stops [Integer] The maximum number of stops in any blueprint path.
  def preload_segments(blueprint_paths, max_stops)
    all_airports = blueprint_paths.flatten.uniq

    # The date range must be wide enough for all potential connections.
    # Each stop can add up to MAX_CONNECTION_HOURS to the journey.
    extension = max_stops * MAX_CONNECTION_HOURS
    end_date = @departure_to.end_of_day + extension

    query = Segment.where(
      airline: @carrier,
      origin_iata: all_airports,
      std: @departure_from.beginning_of_day..end_date
    )

    # Use find_in_batches to process records, building the hash manually
    # to avoid loading everything into memory at once.
    segments_by_origin = Hash.new { |h, k| h[k] = [] }
    query.find_in_batches do |batch|
      batch.each do |segment|
        segments_by_origin[segment.origin_iata] << segment
      end
    end

    segments_by_origin
  end
end