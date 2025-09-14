module Api
  module V1
    class FlightRoutesController < ApplicationController
      def index
        render json: FlightRoutesFinder.new(**flight_routes_params).call
      end

      private

      def flight_routes_params
        params.permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)
              .to_h
              .symbolize_keys
      end
    end
  end
end
