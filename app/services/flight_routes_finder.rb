class FlightRoutesFinder
    MIN_CONNECTION_TIME = 480 # 8 hours in mins
    MAX_CONNECTION_TIME = 2880 # 2 days in mins

    def initialize(carrier:, origin_iata:, destination_iata:, departure_from:, departure_to:)
        @carrier = carrier
        @origin_iata = origin_iata
        @destination_iata = destination_iata
        @departure_from = departure_from.to_date.beginning_of_day
        @departure_to = departure_to.to_date.end_of_day
    end

    def call
        @results ||= begin
            return [] if permitted_routes.empty? || segments.empty?

            permitted_routes.flat_map do |route|
                route_paths(route).flat_map do |path|
                    serialize_sequences(find_sequences(path))
                end
            end
        end
    end

    private

    attr_reader :carrier, :origin_iata, :destination_iata, :departure_from, :departure_to

    # serialization of segment sequences into json
    def serialize_sequences(sequences)
        sequences.map do |sequence|
        {
            origin_iata: sequence.first.origin_iata,
            destination_iata: sequence.last.destination_iata,
            departure_time: sequence.first.std.iso8601,
            arrival_time: sequence.last.sta.iso8601,
            segments: sequence.map { |s| serialize_segment(s) }
        }
        end
    end

    def serialize_segment(s)
        {
        carrier: s.airline,
        segment_number: s.segment_number,
        origin_iata: s.origin_iata,
        destination_iata: s.destination_iata,
        std: s.std.iso8601,
        sta: s.sta.iso8601
        }
    end

    # search for valid segment sequences for a specific path
    def find_sequences(path)
        results = []
        origin, first_stop = path[0], path[1] # 1st airport & 1st destination
        flights_count = path.size - 1 # number of flights required for path

        # fill stack with starting segments: [[seg1], [seg2]]
        stack = (segments[origin] || [])
            .select { |s| s.destination_iata == first_stop }
            .zip

        until stack.empty?
            curr_sequence = stack.pop
            last_segment = curr_sequence.last

            # check if reached route length and arrived at final airport
            if curr_sequence.size == flights_count && last_segment.destination_iata == path.last
                results << curr_sequence
                next
            end

            next_origin = last_segment.destination_iata # next departure airport
            next_dest = path[curr_sequence.size + 1] # next destination airport

            (segments[next_origin] || []).each do |sgmt|
                next unless sgmt.destination_iata == next_dest # correct next departure airport
                next unless valid_connection?(last_segment, sgmt) # if connection is valid

                stack << [ *curr_sequence, sgmt ] # add new sequence to stack
            end
        end

        results
    end

    # check if the connection between segments is valid
    def valid_connection?(last_segment, next_segment)
        transfer_time = (next_segment.std - last_segment.sta) / 60.0
        MIN_CONNECTION_TIME <= transfer_time && transfer_time <= MAX_CONNECTION_TIME
    end

    def permitted_routes
        @permitted_routes ||= PermittedRoute.where(
            carrier: @carrier,
            origin_iata: @origin_iata,
            destination_iata: @destination_iata
        )
    end

    # segments grouped by departure airport
    def segments
        @segments ||= Segment.where(airline: @carrier)
                             .where(std: @departure_from..@departure_to)
                             .order(:std)
                             .group_by(&:origin_iata)
    end

    # generate all possible routes from PermittedRoute
    def route_paths(route)
        [].tap do |paths|
            paths << [ route.origin_iata, route.destination_iata ] if route.direct

            route.transfer_iata_codes.reject(&:blank?).each do |code|
                next unless code.length % 3 == 0
                transfers = code.scan(/.{3}/) # split the code into iata codes of 3 letters
                paths << [ route.origin_iata, *transfers, route.destination_iata ]
            end
        end
    end
end
