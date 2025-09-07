module Api
  module V1
    class RoutesController < ApplicationController
      def search
        @search_form = RouteSearchForm.new(search_params.to_h)

        if @search_form.valid?
          itineraries = RouteFinderService.call(@search_form.attributes.symbolize_keys)
          render json: RouteSerializer.render(itineraries)
        else
          render json: { errors: @search_form.errors.messages }, status: :unprocessable_content
        end
      end

      private

      def search_params
        params.permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)
      end
    end
  end
end
