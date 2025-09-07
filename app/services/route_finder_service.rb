class RouteFinderService
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

  def call
    permitted_route = PermittedRoute.find_by(
      carrier: @carrier,
      origin_iata: @origin_iata,
      destination_iata: @destination_iata
    )

    return [] unless permitted_route

    blueprint_paths = RouteFinder::PermittedRouteParser.call(permitted_route)
    return [] if blueprint_paths.empty?

    preload_segments(blueprint_paths)

    itineraries = blueprint_paths.flat_map do |path|
      RouteFinder::ItineraryBuilder.call(
        blueprint_path: path,
        segments_by_origin: @segments_by_origin,
        departure_from: @departure_from,
        departure_to: @departure_to
      )
    end

    # TODO: Format the itineraries for the final JSON response
    itineraries.count
  end

  private

  def preload_segments(blueprint_paths)
    all_airports = blueprint_paths.flatten.uniq

    # The date range for segments should be wide enough to accommodate connections.
    # We take the user's departure window and add the max connection time.
    end_date = Date.parse(@departure_to).end_of_day + 48.hours

    segments = Segment.where(
      carrier: @carrier,
      origin_iata: all_airports,
      std: Date.parse(@departure_from).beginning_of_day..end_date
    ).to_a

    @segments_by_origin = segments.group_by(&:origin_iata)
  end
end
