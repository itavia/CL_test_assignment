require 'rails_helper'

RSpec.describe 'Routes API - direct and transfer', type: :request do
  let(:carrier) { 'S7' }
  let(:origin)  { 'UUS' }
  let(:dest)    { 'DME' }
  let(:transfer){ 'SVX' }

  before do
    PermittedRoute.create!(carrier: carrier, origin_iata: origin, destination_iata: dest, direct: true, transfer_iata_codes: [transfer])
  end

  it 'returns direct flights within window' do
    Segment.create!(airline: carrier, segment_number: '100', origin_iata: origin, destination_iata: dest,
                    std: Time.zone.parse('2024-01-02 08:00'), sta: Time.zone.parse('2024-01-02 10:30'))
    Segment.create!(airline: carrier, segment_number: '101', origin_iata: origin, destination_iata: dest,
                    std: Time.zone.parse('2024-01-03 08:00'), sta: Time.zone.parse('2024-01-03 10:30'))

    get '/api/v1/routes', params: { carrier: carrier, origin: origin, destination: dest, date_from: '2024-01-01', date_to: '2024-01-03', max_transfers: 0 }

    expect(response).to have_http_status(:ok)
    arr = json
    expect(arr.size).to eq(2)
    expect(arr.all? { |r| r['type'] == 'direct' }).to be true
    # ordered by std ascending
    expect(Time.parse(arr.first['legs'].first['std'])).to be < Time.parse(arr.last['legs'].first['std'])
  end

  it 'returns transfer variants and filters by connection window' do
    # first leg: UUS->SVX
    l1_ok = Segment.create!(airline: carrier, segment_number: '200', origin_iata: origin, destination_iata: transfer,
                    std: Time.zone.parse('2024-01-02 06:00'), sta: Time.zone.parse('2024-01-02 08:00'))
    l1_short = Segment.create!(airline: carrier, segment_number: '201', origin_iata: origin, destination_iata: transfer,
                    std: Time.zone.parse('2024-01-02 06:30'), sta: Time.zone.parse('2024-01-02 07:30'))
    l1_long = Segment.create!(airline: carrier, segment_number: '202', origin_iata: origin, destination_iata: transfer,
                    std: Time.zone.parse('2024-01-02 01:00'), sta: Time.zone.parse('2024-01-02 02:00'))

    # second leg: SVX->DME
    # ok connection: 08:00 -> 09:00 (60 min)
    Segment.create!(airline: carrier, segment_number: '300', origin_iata: transfer, destination_iata: dest,
                    std: Time.zone.parse('2024-01-02 09:00'), sta: Time.zone.parse('2024-01-02 11:30'))
    # too short: 07:50 (20 min)
    Segment.create!(airline: carrier, segment_number: '301', origin_iata: transfer, destination_iata: dest,
                    std: Time.zone.parse('2024-01-02 07:50'), sta: Time.zone.parse('2024-01-02 10:20'))
    # too long: 1 day + 1 hour after
    Segment.create!(airline: carrier, segment_number: '302', origin_iata: transfer, destination_iata: dest,
                    std: Time.zone.parse('2024-01-03 09:10'), sta: Time.zone.parse('2024-01-03 11:40'))

    get '/api/v1/routes', params: { carrier: carrier, origin: origin, destination: dest, date_from: '2024-01-01', date_to: '2024-01-02', max_transfers: 1 }
    expect(response).to have_http_status(:ok)
    arr = json

    # Only one valid transfer pair (200 -> 300)
    transfer_results = arr.select { |r| r['type'] == 'transfer' }
    expect(transfer_results.size).to eq(1)
    r = transfer_results.first
    expect(r['transfer_airport']).to eq(transfer)
    expect(r['connection_minutes']).to eq(60)
  end
end