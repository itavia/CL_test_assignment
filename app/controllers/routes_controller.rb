class RoutesController < ApplicationController
  def index
    service = Routes::SearchService.new(routes_params)

    if service.perform
      render json: service.routes_to_json
    else
      render json: { errors: service.errors.messages }, status: :unprocessable_entity
    end
  end

  private

  def routes_params
    params.permit(:carrier, :origin_iata, :destination_iata, :departure_from, :departure_to)
  end
end


