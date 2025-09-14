# frozen_string_literal: true

class Api::V1::RoutesController < ApplicationController
  # Rails API-only: ensure JSON only, auth — если нужно, тут опции.

  def index
    # Параметры строго по ТЗ
    carrier         = params.require(:carrier).to_s.upcase
    origin_iata     = params.require(:origin_iata).to_s.upcase[0, 3]
    destination_iata= params.require(:destination_iata).to_s.upcase[0, 3]
    departure_from  = parse_date!(params.require(:departure_from)).beginning_of_day
    departure_to    = parse_date!(params.require(:departure_to)).end_of_day

    finder = RouteFinder.new(
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata,
      departure_from: departure_from,
      departure_to: departure_to
    )

    routes = finder.call

    render json: routes
  rescue ActionController::ParameterMissing => e
    render json: { error: "Missing parameter: #{e.param}" }, status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def parse_date!(value)
    Date.parse(value.to_s)
  rescue ArgumentError
    raise ArgumentError, "Invalid date: #{value.inspect}"
  end
end
