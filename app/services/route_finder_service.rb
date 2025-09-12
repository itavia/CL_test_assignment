# frozen_string_literal: true

# Сервис для поиска всех возможных вариантов перелета на основе разрешенных маршрутов и доступных сегментов.
class RouteFinderService
  def self.call(...) = new(...).call

  def initialize(carrier:, origin_iata:, destination_iata:, departure_from:, departure_to:)
    @carrier = carrier
    @origin_iata = origin_iata
    @destination_iata = destination_iata
    @departure_from = Time.zone.parse(departure_from).beginning_of_day
    @departure_to = Time.zone.parse(departure_to).end_of_day
    @all_journeys = []
  end

  def call
    permitted_route = find_permitted_route
    return [] unless permitted_route

    @segments_by_origin = load_relevant_segments

    paths = generate_paths(permitted_route)

    paths.each do |path|
      find_journeys_for_path(path)
    end

    format_journeys(@all_journeys)
  end

  private
    MIN_CONNECTION_TIME = 8.hours
    MAX_CONNECTION_TIME = 48.hours
    private_constant :MIN_CONNECTION_TIME,
                   :MAX_CONNECTION_TIME

  attr_reader :carrier,
              :origin_iata,
              :destination_iata,
              :departure_from,
              :departure_to,
              :segments_by_origin

  def find_permitted_route
    PermittedRoute.find_by(
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata
    )
  end

  def load_relevant_segments
    end_of_search_window = departure_to + 3.days
    Segment.where(airline: carrier, std: departure_from..end_of_search_window)
           .order(:std)
           .group_by(&:origin_iata)
  end

  def generate_paths(permitted_route)
    paths = []
    paths << [ origin_iata, destination_iata ] if permitted_route.direct

    permitted_route.transfer_iata_codes.each do |transfer_code|
      transfer_points = transfer_code.scan(/.{3}/)
      paths << [ origin_iata, *transfer_points, destination_iata ]
    end

    paths
  end

  def find_journeys_for_path(path)
    first_segments = segments_by_origin[path.first]&.select do |segment|
      segment.destination_iata == path[1] && segment.std.between?(departure_from, departure_to)
    end

    return if first_segments.blank?

    first_segments.each do |first_segment|
      find_connections([ first_segment ], path.drop(2))
    end
  end

  def find_connections(current_journey, remaining_path)
    if remaining_path.empty?
      @all_journeys << current_journey
      return
    end

    last_segment = current_journey.last
    next_origin = last_segment.destination_iata
    next_destination = remaining_path.first

    candidate_segments = segments_by_origin[next_origin]&.select do |segment|
      segment.destination_iata == next_destination &&
        valid_connection?(last_segment, segment)
    end

    return if candidate_segments.blank?

    candidate_segments.each do |next_segment|
      find_connections(current_journey + [ next_segment ], remaining_path.drop(1))
    end
  end

  def valid_connection?(prev_segment, next_segment)
    connection_duration = next_segment.std - prev_segment.sta
    connection_duration.between?(MIN_CONNECTION_TIME, MAX_CONNECTION_TIME)
  end

  def format_journeys(journeys)
    journeys.map do |journey_segments|
      {
        origin_iata: journey_segments.first.origin_iata,
        destination_iata: journey_segments.last.destination_iata,
        departure_time: journey_segments.first.std.iso8601,
        arrival_time: journey_segments.last.sta.iso8601,
        segments: format_segments(journey_segments)
      }
    end
  end

  def format_segments(segments)
    segments.map do |segment|
      {
        carrier: segment.airline,
        segment_number: segment.segment_number,
        origin_iata: segment.origin_iata,
        destination_iata: segment.destination_iata,
        std: segment.std.iso8601,
        sta: segment.sta.iso8601
      }
    end
  end
end
