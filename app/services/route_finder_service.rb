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
    # TODO: Implement the actual route finding logic
    []
  end
end
