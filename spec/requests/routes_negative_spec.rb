require 'rails_helper'

RSpec.describe 'Routes API - negative cases', type: :request do
  it 'returns not permitted message when no policy found' do
    get '/api/v1/routes', params: { carrier: 'S7', origin: 'UUS', destination: 'DME', date_from: '2024-01-01', date_to: '2024-01-02' }
    expect(response).to have_http_status(:ok)
    expect(json).to eq({ 'message' => 'Маршрут не разрешён политикой перевозчика', 'data' => [] })
  end

  it 'returns 400 when required params are missing' do
    get '/api/v1/routes', params: { carrier: 'S7', origin: 'UUS' }
    expect(response).to have_http_status(:bad_request)
  end

  it 'does not build transfers if max_transfers=0' do
    PermittedRoute.create!(carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true, transfer_iata_codes: ['SVX'])
    Segment.create!(airline: 'S7', segment_number: '100', origin_iata: 'UUS', destination_iata: 'DME',
                    std: Time.zone.parse('2024-01-02 08:00'), sta: Time.zone.parse('2024-01-02 10:30'))
    # also present legs that could form a transfer, but max_transfers=0 should skip them
    Segment.create!(airline: 'S7', segment_number: '200', origin_iata: 'UUS', destination_iata: 'SVX',
                    std: Time.zone.parse('2024-01-02 06:00'), sta: Time.zone.parse('2024-01-02 08:00'))
    Segment.create!(airline: 'S7', segment_number: '300', origin_iata: 'SVX', destination_iata: 'DME',
                    std: Time.zone.parse('2024-01-02 09:00'), sta: Time.zone.parse('2024-01-02 11:30'))

    get '/api/v1/routes', params: { carrier: 'S7', origin: 'UUS', destination: 'DME', date_from: '2024-01-01', date_to: '2024-01-02', max_transfers: 0 }
    expect(response).to have_http_status(:ok)
    arr = json
    expect(arr.all? { |r| r['type'] == 'direct' }).to be true
  end
end