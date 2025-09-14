require "rails_helper"

RSpec.describe "Api::V1::FlightRoutes", type: :request do
  let(:carrier) { "S7" }
  let(:origin_iata) { "UUS" }
  let(:destination_iata) { "DME" }
  let(:departure_from) { "2024-01-01" }
  let(:departure_to) { "2024-01-07" }


  def request_routes(params = {})
    get "/api/v1/flight_routes", params: {
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata,
      departure_from: departure_from,
      departure_to: departure_to
    }.merge(params)
  end


  it "returns 200 OK with results" do
    create(:permitted_route, carrier: carrier, origin_iata: origin_iata, destination_iata: destination_iata, direct: true)
    create(:segment, airline: carrier, origin_iata: origin_iata, destination_iata: destination_iata,
                     std: "2024-01-01T08:00:00Z", sta: "2024-01-01T16:00:00Z")

    request_routes
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body, symbolize_names: true)
    expect(body).to be_an(Array)
    expect(body.first).to include(
      origin_iata: "UUS",
      destination_iata: "DME"
    )
  end

  it "returns [] if no routes found" do
    request_routes
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body, symbolize_names: true)
    expect(body).to eq([])
  end


  it "returns [] if required params are missing" do
    request_routes(carrier: nil, origin_iata: nil)
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body, symbolize_names: true)
    expect(body).to eq([])
  end
end
