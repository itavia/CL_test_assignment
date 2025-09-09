class GoFlightSearchService
  # @param params [Hash] The search parameters from the controller.
  # @option params [String] :carrier The airline carrier code.
  # @option params [String] :origin_iata The origin airport IATA code.
  # @option params [String] :destination_iata The destination airport IATA code.
  # @option params [Date] :departure_from The start of the departure window.
  # @option params [Date] :departure_to The end of the departure window.
  # @return [Array<Array<Segment>>] A list of found itineraries, where each itinerary is an array of Segment objects.
  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @params = params
    @client = build_client
  end

  def call
    request = Proto::SearchRequest.new(
      carrier: @params[:carrier],
      origin_iata: @params[:origin_iata],
      destination_iata: @params[:destination_iata],
      departure_from: @params[:departure_from].to_s,
      departure_to: @params[:departure_to].to_s
    )

    response = @client.search_routes(request)

    map_response_to_ruby_objects(response)
  rescue GRPC::BadStatus => e
    Rails.logger.error("gRPC call failed: #{e.message}")
    [] # Return empty array on gRPC error
  end

  private

  def build_client
    # In a real app, the address would come from config/env vars
    go_app_address = ENV.fetch('GO_APP_GRPC_ADDRESS', 'go_app:50051')
    Proto::FlightSearchService::Stub.new(go_app_address, :this_channel_is_insecure)
  end

  def map_response_to_ruby_objects(response)
    response.itineraries.map do |pb_itinerary|
      itinerary = Itinerary.new(
        origin_iata: pb_itinerary.origin_iata,
        destination_iata: pb_itinerary.destination_iata,
        departure_time: Time.at(pb_itinerary.departure_time.seconds, pb_itinerary.departure_time.nanos / 1000.0),
        arrival_time: Time.at(pb_itinerary.arrival_time.seconds, pb_itinerary.arrival_time.nanos / 1000.0)
      )
      itinerary.segments = pb_itinerary.segments.map do |pb_segment|
        Segment.new(
          airline: pb_segment.carrier,
          segment_number: pb_segment.segment_number,
          origin_iata: pb_segment.origin_iata,
          destination_iata: pb_segment.destination_iata,
          std: Time.at(pb_segment.std.seconds, pb_segment.std.nanos / 1000.0),
          sta: Time.at(pb_segment.sta.seconds, pb_segment.sta.nanos / 1000.0)
        )
      end
      itinerary.segments # Return the array of segments for the serializer
    end
  end
end

# PORO to represent a Segment, matching the structure expected by RouteSerializer
# This is needed because the gRPC generated objects are not ActiveRecord models.
class Segment
  attr_accessor :airline, :segment_number, :origin_iata, :destination_iata, :std, :sta

  def initialize(attributes = {})
    attributes.each do |key, value|
      send("#{key}=", value)
    end
  end
end

# PORO to represent an Itinerary, matching the structure expected by RouteSerializer
# This is needed because the gRPC generated objects are not ActiveRecord models.
class Itinerary
  attr_accessor :origin_iata, :destination_iata, :departure_time, :arrival_time, :segments

  def initialize(attributes = {})
    attributes.each do |key, value|
      send("#{key}=", value)
    end
  end
end
