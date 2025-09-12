# This service is the main entry point for the flight search logic.
# It orchestrates the process of finding flight itineraries based on
# permitted routes and available flight segments.
class RouteFinderService
  MAX_CONNECTION_HOURS = 48.hours

  # @param params [Hash] The search parameters from the controller.
  # @return [Array<Array<Segment>>] A list of found itineraries.
  def self.call(params)
    new(params).call
  end

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
    return [] unless find_permitted_route &&
                     parse_blueprint_paths &&
                     preload_segments

    build_itineraries
  end

  private

  def find_permitted_route
    @permitted_route = PermittedRoute.find_by(
      carrier: @carrier,
      origin_iata: @origin_iata,
      destination_iata: @destination_iata
    )
    @permitted_route.present?
  end

  def parse_blueprint_paths
    @blueprint_paths = RouteFinder::PermittedRouteParser.call(@permitted_route)
    @blueprint_paths.present?
  end

  # Preloads all segments that could possibly be part of a valid itinerary.
  # @return [Boolean] True on success.
  def preload_segments
    all_airports = @blueprint_paths.flatten.uniq
    end_date = calculate_search_end_date(@blueprint_paths)

    query = Segment.where(
      airline: @carrier,
      origin_iata: all_airports,
      std: @departure_from.beginning_of_day..end_date
    )

    @segments_by_origin = group_segments_by_origin(query)
    true
  end

  def build_itineraries
    @blueprint_paths.flat_map do |path|
      RouteFinder::ItineraryBuilder.call(
        blueprint_path: path,
        segments_by_origin: @segments_by_origin,
        departure_from: @departure_from,
        departure_to: @departure_to
      )
    end
  end

  def calculate_search_end_date(blueprint_paths)
    max_stops = blueprint_paths.map { |path| path.length - 2 }.max
    max_stops = [0, max_stops].max # Ensure it's not negative

    @departure_to.end_of_day + (max_stops * MAX_CONNECTION_HOURS)
  end

  def group_segments_by_origin(query)
    segments_by_origin = Hash.new { |h, k| h[k] = [] }
    query.find_in_batches do |batch|
      batch.each do |segment|
        segments_by_origin[segment.origin_iata] << segment
      end
    end
    segments_by_origin
  end
end