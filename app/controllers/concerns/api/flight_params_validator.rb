# frozen_string_literal: true

module Api::FlightParamsValidator
  extend ActiveSupport::Concern

  private

  def validate_flight_params
    permitted = params.permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)

    return nil unless permitted[:carrier].present? &&
      permitted[:origin_iata].to_s.length == 3 &&
      permitted[:destination_iata].to_s.length == 3 &&
      permitted[:departure_from].present? &&
      permitted[:departure_to].present?

    permitted
  end
end
