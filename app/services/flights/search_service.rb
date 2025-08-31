# frozen_string_literal: true

require "set"

module Flights
  class SearchService
    def self.call(flight_params)
      new(flight_params).send(:call)
    end

    def initialize(flight_params)
      @flight_params = flight_params
    end

    private

    def call
      permitted_route = fetch_permitted_route
      return [] if permitted_route.blank?

      routes = build_routes(permitted_route)
      queries = build_queries(routes)
      build_result(queries)
    end

    private

    def fetch_permitted_route
      PermittedRoute.where(@flight_params.except(:departure_from, :departure_to)).first
    end

    def build_routes(permitted_route)
      routes = []
      origin      = @flight_params[:origin_iata]
      destination = @flight_params[:destination_iata]

      routes << [ origin, destination ] if permitted_route.direct?

      permitted_route.transfer_iata_codes.each do |transfer|
        codes = transfer.scan(/.{3}/)
        routes << [ origin, *codes, destination ]
      end

      routes
    end

    def build_queries(routes)
      routes.map do |route|
        RoutesQuery.call(@flight_params.merge(route:))
      end
    end

    def build_result(queries)
      result = []

      queries.each do |sql, params|
        segments = ActiveRecord::Base.connection.exec_query(sql, "SegmentsQuery", params).to_a
        result << build_possible_routes_with_dfs(segments)
      end

      result.flatten
    end

    def build_possible_routes_with_dfs(segments)
      routes = []
      origin = @flight_params[:origin_iata]
      destination = @flight_params[:destination_iata]

      segments_by_origin = segments.map(&:deep_symbolize_keys).group_by { |s| s[:origin_iata] }

      visited_routes = Set.new

      dfs = lambda do |current_airport, path|
        return if path.size > segments.size

        if current_airport == destination
          route_key = path.map { |s| s[:segment_number] }.join("-")

          unless visited_routes.include?(route_key)
            visited_routes << route_key
            routes << path
          end

          return
        end

        next_segments = segments_by_origin[current_airport] || []

        next_segments.each do |segment|
          next if path.any? { |s| s[:segment_number] == segment[:segment_number] }

          if path.empty? || connection_time_valid?(path.last[:sta], segment[:std])
            dfs.call(segment[:destination_iata], path + [ segment ])
          end
        end
      end

      dfs.call(origin, [])
      routes.map { |segments| build_route_hash(segments) }
    end

    def connection_time_valid?(prev_arrival, next_departure)
      return true unless prev_arrival

      diff_minutes = (next_departure - prev_arrival) / 60
      diff_minutes >= Flights::Config::MIN_CONNECTION_TIME && diff_minutes <= Flights::Config::MAX_CONNECTION_TIME
    end

    def build_route_hash(segments)
      {
        origin_iata: segments.first[:origin_iata],
        destination_iata: segments.last[:destination_iata],
        departure_time: segments.first[:std],
        arrival_time: segments.last[:sta],
        segments: build_segments(segments)
      }
    end

    def build_segments(segments)
      segments.map do |segment|
        {
          carrier: segment[:airline],
          segment_number: segment[:segment_number],
          origin_iata: segment[:origin_iata],
          destination_iata: segment[:destination_iata],
          std: segment[:std],
          sta: segment[:sta]
        }
      end
    end
  end
end
