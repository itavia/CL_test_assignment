# frozen_string_literal: true

module V1
  module Flights
    class RoutesController < V1::BaseController
      def index
        result = Operations::Flights::V1::FindRoutes.new.call(q_params.to_h)
        case result
        in Success[found_routes]
          render json: found_routes
        in Failure[error_code, error_description]
          render json: { error_code: error_code, error_description: error_description }
        end
      end

      private

      def q_params
        params.permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)
      end
    end
  end
end
