# frozen_string_literal: true

module Api
  module Flights
    class SearchController < ApplicationController
      include Api::FlightParamsValidator

      def call
        flight_params = validate_flight_params
        return render_error("Invalid parameters") unless flight_params

        flights = ::Flights::SearchService.call(flight_params)
        render_success(flights)
      end
    end
  end
end
