module Routes
  class SearchService
    include ActiveModel::API

    attr_accessor :carrier, :origin_iata, :destination_iata, :departure_from, :departure_to

    validates :carrier, presence: true
    validates :origin_iata, presence: true, length: { is: 3 }
    validates :destination_iata, presence: true, length: { is: 3 }
    validates :departure_from, presence: true
    validates :departure_to, presence: true

    def perform
      return false unless valid?

      permitted_route =
        PermittedRoute.find_by(
          carrier: @carrier,
          origin_iata: @origin_iata,
          destination_iata: @destination_iata
        )

      return true if permitted_route.blank?

      route_paths(permitted_route).each do |segment_paths|
        route_segments_service =
          SearchSegmentsService.new(
            carrier: carrier,
            departure_from: departure_from,
            departure_to: departure_to,
            segment_paths: segment_paths
          )

        route_segments_service.perform
        routes.push(*route_segments_service.segments)
      end

      true
    end

    def routes_to_json
      routes.map do |route_segments|
        {
          origin_iata: @origin_iata,
          destination_iata: @destination_iata,
          departure_time: route_segments.first.std.iso8601(3),
          arrival_time: route_segments.last.sta.iso8601(3),
          segments:
            route_segments.map do |segment|
              {
                carrier: segment.airline,
                segment_number: segment.segment_number,
                origin_iata: segment.origin_iata,
                destination_iata: segment.destination_iata,
                std: segment.std.iso8601(3),
                sta: segment.sta.iso8601(3)
              }
            end
        }
      end
    end

    def routes
      @routes ||= []
    end

    def departure_from=(value)
      @departure_from = Time.zone.parse(value.to_s)&.beginning_of_day
    end

    def departure_to=(value)
      @departure_to = Time.zone.parse(value.to_s)&.end_of_day
    end

    private

    def route_paths(permitted_route)
      paths = []

      if permitted_route.direct
        paths << [[permitted_route.origin_iata, permitted_route.destination_iata]]
      end

      permitted_route.transfer_iata_codes.each do |code|
        stops = code.scan(/.{3}/)
        paths.push(
         ([permitted_route.origin_iata] + stops + [permitted_route.destination_iata]).each_cons(2).to_a
        )
      end

      paths
    end
  end
end


