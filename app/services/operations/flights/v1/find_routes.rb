# frozen_string_literal: true

module Operations
  module Flights
    module V1
      class FindRoutes
        include Dry::Monads[:result, :do]

        MIN_CONNECTION_TIME = 480.minutes  # минимальное время для пересадки, мин (8 часов)
        MAX_CONNECTION_TIME = 2880.minutes # максимальное время ожидания, мин (48 часов)

        def call(params)
          validated_params = yield validate(params)
          permitted_route = find_permitted_route(validated_params.to_h)
          return Success([]) unless permitted_route

          possible_routes = generate_possible_paths(permitted_route)
          departure_range = Range.new(*validated_params.to_h.slice(:departure_from, :departure_to).values)
          airline = validated_params[:carrier]

          threads = []
          mutex = Mutex.new
          available_segments = []

          possible_routes.each do |route|
            threads << Thread.new do
              ActiveRecord::Base.connection_pool.with_connection do
                segments = find_segments_chains(airline, route, departure_range, [])
                if segments.any?
                  formatted = format_segments(segments)
                  mutex.synchronize { available_segments << formatted }
                end
              end
            end
          end

          threads.each(&:join)
          Success[available_segments]
        end

        private

        def validate(params)
          validation = Validations::Flights::V1::FindRoutes.new
          validation.call(params).to_monad.
            or { |failure| Failure[:validation_error, failure.errors.to_h] }
        end

        def find_permitted_route(params)
          PermittedRoute.find_by(params.slice(:carrier, :origin_iata, :destination_iata))
        end

        def generate_possible_paths(permitted_route)
          origin = permitted_route.origin_iata
          destination = permitted_route.destination_iata
          paths = []
          paths << [origin, destination] if permitted_route.direct?
          permitted_route.transfer_iata_codes.each do |transfer_codes|
            transfers = transfer_codes.scan(/.{3}/)
            paths << [origin, *transfers, destination]
          end
          paths
        end

        def find_segments_chains(airline, routes, departure_range, available_segments = [])
          return available_segments if routes.size < 2

          current_origin = routes.first
          current_destination = routes.second
          last_arrival_time = available_segments.last&.sta
          possible_segments = find_segments(airline, current_origin, current_destination, departure_range, last_arrival_time)
          possible_segments.flat_map do |segment|
            find_segments_chains(airline, routes.drop(1), departure_range, available_segments + [segment])
          end
        end

        def find_segments(airline, origin_iata, destination_iata, departure_range, last_arrival_time)
          if last_arrival_time.nil?
            Segment.where(airline: airline, origin_iata: origin_iata, destination_iata: destination_iata, std: departure_range)
          else
            min_departure = last_arrival_time + MIN_CONNECTION_TIME
            max_departure = last_arrival_time + MAX_CONNECTION_TIME
            Segment.where(airline: airline, origin_iata: origin_iata, destination_iata: destination_iata, std: min_departure..max_departure)
          end
        end

        def format_segments(segments)
          {
            origin_iata: segments.first.origin_iata,
            destination_iata: segments.last.destination_iata,
            departure_time: segments.first.std,
            arrival_time: segments.last.sta,
            segments: segments.map { |segment|
              {
                carrier: segment.airline,
                segment_number: segment.segment_number,
                origin_iata: segment.origin_iata,
                destination_iata: segment.destination_iata,
                std: segment.std,
                sta: segment.sta
              }
            }
          }
        end
      end
    end
  end
end
