# frozen_string_literal: true

module Api
  module V1
    class RoutesController < ApplicationController
      before_action :validate_search_params

      # GET /api/v1/routes/search
      def search
        result = RouteFinderService.call(**search_params.to_h.symbolize_keys)
        render json: result, status: :ok
      rescue ArgumentError => e
        render_error("Invalid date format: #{e.message}", :bad_request)
      end

      private

      def search_params
        params.permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)
      end

      def validate_search_params
        required_params = %i[carrier origin_iata destination_iata departure_from departure_to]
        missing_params = required_params.select { |p| params[p].blank? }

        return if missing_params.empty?

        render_error("Missing required parameters: #{missing_params.join(', ')}", :bad_request)
      end

      def render_error(message, status)
        render json: { error: message }, status: status
      end
    end
  end
end
