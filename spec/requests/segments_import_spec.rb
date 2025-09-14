require 'rails_helper'

RSpec.describe 'Segments import', type: :request do
  it 'imports a batch successfully' do
    payload = {
      segments: [
        { airline: 'S7', segment_number: '100', origin_iata: 'UUS', destination_iata: 'DME', std: '2024-01-02T08:00:00Z', sta: '2024-01-02T10:30:00Z' },
        { airline: 'S7', segment_number: '101', origin_iata: 'UUS', destination_iata: 'SVX', std: '2024-01-02T06:00:00Z', sta: '2024-01-02T08:00:00Z' }
      ]
    }
    post '/api/v1/segments', params: payload
    expect(response).to have_http_status(:ok)
    body = json
    expect(body['data']).to include('imported_count' => 2)
    expect(Segment.count).to eq(2)
  end

  it 'partially imports and reports errors' do
    payload = {
      segments: [
        { airline: 'S7', segment_number: '200', origin_iata: 'UUS', destination_iata: 'DME' },
        { segment_number: '201', origin_iata: 'UUS', destination_iata: 'DME' } # missing airline
      ]
    }
    post '/api/v1/segments', params: payload
    expect(response).to have_http_status(:unprocessable_entity)
    body = json
    expect(body['data']).to include('imported_count' => 1)
    expect(body['errors']).to be_an(Array)
    expect(body['errors'].first['error']).to match(/Airline can't be blank|Airline can't be blank/i)
  end
end