require 'rails_helper'

RSpec.describe 'Api::V1::Routes', type: :request do
  include FactoryBot::Syntax::Methods

  describe 'POST /api/v1/routes/search' do
    let(:headers) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' } }
    let(:params) do
      {
        carrier: 'S7',
        origin_iata: 'UUS',
        destination_iata: 'DME',
        departure_from: '2024-01-01',
        departure_to: '2024-01-07'
      }
    end

    context 'when a valid route is found' do
      let!(:permitted_route) { create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true) }
      let!(:segment) { create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'DME', std: Time.zone.parse('2024-01-02T10:00:00Z')) }

      before do
        post '/api/v1/routes/search', params: params.to_json, headers: headers
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the found route in the correct format' do
        json_response = JSON.parse(response.body)
        expect(json_response.size).to eq(1)
        expect(json_response.first['origin_iata']).to eq('UUS')
        expect(json_response.first['destination_iata']).to eq('DME')
        expect(json_response.first['segments'].size).to eq(1)
        expect(json_response.first['segments'].first['segment_number']).to eq(segment.segment_number)
      end
    end

    context 'when no route is found' do
      before do
        post '/api/v1/routes/search', params: params.to_json, headers: headers
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns an empty array' do
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end

    context 'with invalid parameters' do
      it 'returns a 422 error if a parameter is missing' do
        post '/api/v1/routes/search', params: params.except(:carrier).to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']['carrier']).to include("can't be blank")
      end

      it 'returns a 422 error for malformed IATA codes' do
        post '/api/v1/routes/search', params: params.merge(origin_iata: 'US').to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']['origin_iata']).to include("must be a 3-letter uppercase IATA code")
      end

      it 'returns a 422 error if departure_to is before departure_from' do
        post '/api/v1/routes/search', params: params.merge(departure_to: '2023-12-31').to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']['departure_to']).to include("can't be before departure_from")
      end

      it 'returns a 422 error for an invalid date format' do
        post '/api/v1/routes/search', params: params.merge(departure_from: 'not-a-date').to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']['departure_from']).to include("can't be blank")
      end
    end
  end
end
