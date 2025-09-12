# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Routes', type: :request do
  describe 'GET /api/v1/routes/search' do
    let(:base_params) do
      {
        carrier: 'S7',
        origin_iata: 'UUS',
        destination_iata: 'DME',
        departure_from: '2024-01-01',
        departure_to: '2024-01-07'
      }
    end

    context 'когда найдены валидные маршруты' do
      before do
        permitted_route = create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true)
        create(:segment,
               airline: permitted_route.carrier,
               origin_iata: permitted_route.origin_iata,
               destination_iata: permitted_route.destination_iata,
               std: Time.zone.parse('2024-01-03 10:00Z'),
               sta: Time.zone.parse('2024-01-03 18:00Z'))
      end

      it 'возвращает статус 200 OK и список маршрутов' do
        get search_api_v1_routes_path, params: base_params

        expect(response).to have_http_status(:ok)
        expect(response_body).to be_an(Array)
        expect(response_body.size).to eq(1)
        expect(response_body.first[:origin_iata]).to eq('UUS')
        expect(response_body.first[:destination_iata]).to eq('DME')
        expect(response_body.first[:segments].size).to eq(1)
        expect(response_body.first[:segments].first[:std]).to eq('2024-01-03T10:00:00Z')
      end
    end

    context 'когда маршруты не найдены' do
      before do
        create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true)
      end

      it 'возвращает статус 200 OK и пустой массив' do
        get search_api_v1_routes_path, params: base_params

        expect(response).to have_http_status(:ok)
        expect(response_body).to eq([])
      end
    end

    context 'когда отсутствуют обязательные параметры' do
      it 'возвращает статус 400 Bad Request и сообщение об ошибке' do
        incomplete_params = base_params.except(:departure_to)

        get search_api_v1_routes_path, params: incomplete_params

        expect(response).to have_http_status(:bad_request)
        expect(response_body[:error]).to include('Missing required parameters: departure_to')
      end
    end
  end
end
