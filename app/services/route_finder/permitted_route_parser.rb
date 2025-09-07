module RouteFinder
  class PermittedRouteParser
    def self.call(permitted_route)
      new(permitted_route).call
    end

    def initialize(permitted_route)
      @route = permitted_route
      @origin = permitted_route.origin_iata
      @destination = permitted_route.destination_iata
    end

    def call
      paths = []
      paths << [@origin, @destination] if @route.direct

      @route.transfer_iata_codes.each do |transfer_code|
        transfer_airports = transfer_code.scan(/.{3}/)
        # Only add a path if the scan found valid 3-letter codes and the original
        # string was composed entirely of 3-letter codes.
        if !transfer_airports.empty? && transfer_code.length == transfer_airports.join.length
          paths << [@origin, *transfer_airports, @destination]
        end
      end

      paths
    end
  end
end
