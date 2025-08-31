# frozen_string_literal: true

RSpec.describe Api::Flights::SearchController, type: :controller do
  describe "POST #call" do
    let(:valid_params) do
      {
        carrier: "S7",
        origin_iata: "UUS",
        destination_iata: "DME",
        departure_from: "2024-01-01",
        departure_to: "2024-01-07"
      }
    end

    let(:valid_response) { { "success" => true, "data" => [] } }

    it "returns valid_response" do
      post :call, params: valid_params, as: :json
      expect(JSON.parse(response.body)).to eq(valid_response)
    end

    it "returns status 200" do
      post :call, params: valid_params, as: :json
      expect(response).to have_http_status(:ok)
    end

    context "when invalid params" do
      let(:invalid_params) { {} }

      it "returns status 422" do
        post :call, params: invalid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
