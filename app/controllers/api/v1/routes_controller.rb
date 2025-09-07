module Api
  module V1
    class RoutesController < ApplicationController
      def search
        itineraries = RouteFinderService.call(search_params)
        render json: RouteSerializer.render(itineraries)
      end

      private

      def search_params
        params.permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)
      end
    end
  end
end
