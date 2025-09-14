require 'rails_helper'

RSpec.describe 'Permitted routes import', type: :request do
  it 'imports and normalizes IATA codes' do
    payload = { routes: [ { carrier: 's7', origin_iata: 'uus', destination_iata: 'dme', direct: true, transfer_iata_codes: ['svx','ovb'] } ] }
    post '/api/v1/permitted_routes', params: payload
    expect(response).to have_http_status(:ok)
    body = json
    expect(body['data']).to include('imported_count' => 1)
    pr = PermittedRoute.first
    expect(pr.carrier).to eq('s7') # controller does not upper, model stores as sent
    # но в /routes контроллер приводит origin/dest к upper, так что здесь проверим, что хранится ровно то, что прислали
    expect(pr.origin_iata).to eq('uus')
    expect(pr.destination_iata).to eq('dme')
    expect(pr.transfer_iata_codes).to eq(%w[SVX OVB]) # контроллер нормализует коды пересадки
  end

  it 'errors on empty payload' do
    post '/api/v1/permitted_routes', params: { routes: [] }
    expect(response).to have_http_status(:bad_request)
  end
end