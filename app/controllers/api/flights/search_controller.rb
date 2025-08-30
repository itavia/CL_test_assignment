# frozen_string_literal: true

module Api
  module Flights
    class SearchController < ApplicationController
      include Api::FlightParamsValidator

      def call
        params_validator = validate_flight_params
        return render_error("Invalid parameters") unless params_validator

        flights = ::Flights::SearchService.call(params_validator)
        render_success(flights)
      end
    end
  end
end
