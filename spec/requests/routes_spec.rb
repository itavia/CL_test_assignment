# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Routes API", type: :request do
  before do
    PermittedRoute.create!(
      carrier: "S7", origin_iata: "UUS", destination_iata: "DME",
      direct: true, transfer_iata_codes: []
    )
    Segment.create!(
      airline: "S7", segment_number: "9999",
      origin_iata: "UUS", destination_iata: "DME",
      std: Time.zone.parse("2024-01-02 08:00:00 UTC"),
      sta: Time.zone.parse("2024-01-02 12:00:00 UTC")
    )
  end

  it "returns routes in the format from the spec" do
    get "/api/v1/routes", params: {
      carrier: "S7",
      origin_iata: "UUS",
      destination_iata: "DME",
      departure_from: "2024-01-01",
      departure_to: "2024-01-07"
    }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to be_a(Array)
    expect(body.first).to include("origin_iata", "destination_iata", "departure_time", "arrival_time", "segments")
    expect(body.first["segments"].first).to include("carrier", "segment_number", "origin_iata", "destination_iata", "std", "sta")
  end

  it "validates required params" do
    get "/api/v1/routes", params: { carrier: "S7" }
    expect(response).to have_http_status(:unprocessable_entity)
    err = JSON.parse(response.body)["error"]
    expect(err).to match(/Missing parameter/)
  end
end
