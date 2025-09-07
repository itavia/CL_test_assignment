module RouteFinder
  # This class is responsible for parsing a single PermittedRoute record
  # into a list of "blueprint paths". Each blueprint path is an array
  # of IATA codes representing a possible sequence of airports.
  # Example: ["UUS", "OVB", "DME"]
  class PermittedRouteParser
    # @param permitted_route [PermittedRoute] The route rule to parse.
    # @return [Array<Array<String>>] A list of blueprint paths.
    def self.call(permitted_route)
      new(permitted_route).call
    end

    # @param permitted_route [PermittedRoute] The route rule to parse.
    def initialize(permitted_route)
      @route = permitted_route
      @origin = permitted_route.origin_iata
      @destination = permitted_route.destination_iata
    end

    # Executes the parsing logic.
    # @return [Array<Array<String>>] A list of blueprint paths.
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
