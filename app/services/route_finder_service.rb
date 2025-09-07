class RouteFinderService
  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @carrier = params[:carrier]
    @origin_iata = params[:origin_iata]
    @destination_iata = params[:destination_iata]
    @departure_from = params[:departure_from]
    @departure_to = params[:departure_to]
  end

  def call
    permitted_route = PermittedRoute.find_by(
      carrier: @carrier,
      origin_iata: @origin_iata,
      destination_iata: @destination_iata
    )

    return [] unless permitted_route

    # TODO: Continue with the next steps
    []
  end
end
