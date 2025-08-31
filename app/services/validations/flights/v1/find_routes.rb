# frozen_string_literal: true

module Validations
  module Flights
    module V1
      class FindRoutes < Dry::Validation::Contract
        params do
          required(:carrier).filled(:string)
          required(:origin_iata).filled(:string, size?: 3)
          required(:destination_iata).filled(:string, size?: 3)
          required(:departure_from).filled(:date)
          required(:departure_to).filled(:date)
        end
      end
    end
  end
end
