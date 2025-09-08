module Api
  module V1
    class RoutesController < ApplicationController
      # GET /api/v1/routes/search
      #
      # Accepts a flight search query and returns possible flight itineraries.
      # It uses a Form Object for validation and a Service Object to encapsulate
      # the complex search logic.
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

      # Strong Parameters to permit the allowed keys for the search.
      #
      # @return [ActionController::Parameters] The permitted parameters.
      def search_params
        params.permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)
      end
    end
  end
end
