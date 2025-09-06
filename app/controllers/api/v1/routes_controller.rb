module Api
  module V1
    class RoutesController < ApplicationController
      def search
        routes = RouteFinderService.call(search_params)
        render json: routes
      end

      private

      def search_params
        params.require(:route).permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)
      end
    end
  end
end
