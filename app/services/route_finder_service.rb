class RouteFinderService
  MIN_CONNECTION_TIME = 480 * 60 # 8 hours in seconds
  MAX_CONNECTION_TIME = 2880 * 60 # 48 hours in seconds

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @carrier = params[:carrier]
    @origin_iata = params[:origin_iata]
    @destination_iata = params[:destination_iata]
    @departure_from = Time.parse(params[:departure_from])
    @departure_to = Time.parse(params[:departure_to]).end_of_day
  end

  def call
    return [] unless permitted_route

    blueprint_paths = generate_blueprint_paths
    segments_by_origin = load_segments(blueprint_paths)
    found_itineraries = build_itineraries(blueprint_paths, segments_by_origin)

    format_itineraries(found_itineraries)
  end

  private

  def format_itineraries(itineraries)
    itineraries.map do |segments|
      {
        origin_iata: segments.first.origin_iata,
        destination_iata: segments.last.destination_iata,
        departure_time: segments.first.std,
        arrival_time: segments.last.sta,
        segments: segments.map do |segment|
          {
            carrier: segment.airline,
            segment_number: segment.segment_number,
            origin_iata: segment.origin_iata,
            destination_iata: segment.destination_iata,
            std: segment.std,
            sta: segment.sta
          }
        end
      }
    end
  end

  attr_reader :carrier, :origin_iata, :destination_iata, :departure_from, :departure_to

  def permitted_route
    @permitted_route ||= PermittedRoute.find_by(
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata
    )
  end

  def generate_blueprint_paths
    paths = []
    paths << [origin_iata, destination_iata] if permitted_route.direct

    permitted_route.transfer_iata_codes.each do |transfer_code|
      transfer_airports = transfer_code.scan(/.{3}/)
      paths << [origin_iata, *transfer_airports, destination_iata]
    end

    paths
  end

  def load_segments(blueprint_paths)
    airport_iatas = blueprint_paths.flatten.uniq

    # We load all potentially relevant segments into memory and filter them later.
    # This is more efficient than multiple DB queries inside the search algorithm.
    Segment.where(
      carrier: carrier,
      origin_iata: airport_iatas,
      destination_iata: airport_iatas
    ).group_by(&:origin_iata)
  end

  def build_itineraries(blueprint_paths, segments_by_origin)
    found_itineraries = []

    blueprint_paths.each do |path|
      find_connections(path, [], segments_by_origin, found_itineraries)
    end

    found_itineraries
  end

  def find_connections(blueprint, current_itinerary, segments_by_origin, results)
    if current_itinerary.empty?
      # Start of a new search
      origin = blueprint.first
      (segments_by_origin[origin] || []).each do |segment|
        if segment.destination_iata == blueprint[1] && segment.std.between?(departure_from, departure_to)
          find_connections(blueprint, [segment], segments_by_origin, results)
        end
      end
    else
      # Continue building the itinerary
      last_segment = current_itinerary.last
      current_destination_index = blueprint.index(last_segment.destination_iata)

      # Base case: we have reached the final destination
      if current_destination_index == blueprint.size - 1
        results << current_itinerary
        return
      end

      next_origin_iata = last_segment.destination_iata
      next_destination_iata = blueprint[current_destination_index + 1]

      (segments_by_origin[next_origin_iata] || []).each do |next_segment|
        if next_segment.destination_iata == next_destination_iata
          connection_time = next_segment.std - last_segment.sta
          if connection_time.between?(MIN_CONNECTION_TIME, MAX_CONNECTION_TIME)
            find_connections(blueprint, current_itinerary + [next_segment], segments_by_origin, results)
          end
        end
      end
    end
  end
end