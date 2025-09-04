class FlyRoutesController < ApplicationController
  include Dry::Monads::Result::Mixin

  def show
    res = FlyRoutes::FlyRoutesService.new.call(show_params)

    case res
    in Success[ *routes ]
    render json: Alba.serialize(routes, with: FlightResource)
    in Failure
    end
  end

  private

  def show_params
    params.expect(fly_route: [ :carrier, :origin_iata, :destination_iata, :departure_from, :departure_to ])
  end
end
