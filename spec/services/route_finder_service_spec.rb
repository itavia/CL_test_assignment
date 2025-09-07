require 'rails_helper'

RSpec.describe RouteFinderService do
  include FactoryBot::Syntax::Methods

  describe '.call' do
    let(:params) do
      {
        carrier: 'S7',
        origin_iata: 'UUS',
        destination_iata: 'DME',
        departure_from: '2024-01-01',
        departure_to: '2024-01-07'
      }
    end

    context 'when a direct flight is available' do
      let!(:permitted_route) { create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true) }
      let!(:segment) { create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'DME', std: Time.parse('2024-01-02T10:00:00Z'), sta: Time.parse('2024-01-02T14:00:00Z')) }

      it 'finds the direct flight' do
        result = described_class.call(params)
        expect(result.size).to eq(1)
        expect(result.first.size).to eq(1)
        expect(result.first.first.segment_number).to eq(segment.segment_number)
      end
    end

    context 'when a flight with one transfer is available' do
      let!(:permitted_route) { create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: false, transfer_iata_codes: ['OVB']) }
      let!(:segment1) { create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'OVB', std: Time.parse('2024-01-02T10:00:00Z'), sta: Time.parse('2024-01-02T14:00:00Z')) }
      let!(:segment2) { create(:segment, airline: 'S7', origin_iata: 'OVB', destination_iata: 'DME', std: Time.parse('2024-01-03T02:00:00Z'), sta: Time.parse('2024-01-03T06:00:00Z')) } # 12h connection

      it 'finds the flight with one transfer' do
        result = described_class.call(params)
        expect(result.size).to eq(1)
        expect(result.first.size).to eq(2)
        expect(result.first.first.segment_number).to eq(segment1.segment_number)
        expect(result.first.second.segment_number).to eq(segment2.segment_number)
      end
    end

    context 'when a flight with a double transfer is available' do
      let!(:permitted_route) { create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: false, transfer_iata_codes: ['VVOOVB']) }
      let!(:segment1) { create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'VVO', std: Time.parse('2024-01-01T10:00:00Z'), sta: Time.parse('2024-01-01T14:00:00Z')) }
      let!(:segment2) { create(:segment, airline: 'S7', origin_iata: 'VVO', destination_iata: 'OVB', std: Time.parse('2024-01-02T02:00:00Z'), sta: Time.parse('2024-01-02T06:00:00Z')) } # 12h connection
      let!(:segment3) { create(:segment, airline: 'S7', origin_iata: 'OVB', destination_iata: 'DME', std: Time.parse('2024-01-02T18:00:00Z'), sta: Time.parse('2024-01-02T22:00:00Z')) } # 12h connection

      it 'finds the flight with two transfers' do
        result = described_class.call(params)
        expect(result.size).to eq(1)
        expect(result.first.size).to eq(3)
        expect(result.first.map(&:segment_number)).to eq([segment1.segment_number, segment2.segment_number, segment3.segment_number])
      end
    end

    context 'when connection time is too short' do
      let!(:permitted_route) { create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: false, transfer_iata_codes: ['OVB']) }
      let!(:segment1) { create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'OVB', std: Time.parse('2024-01-02T10:00:00Z'), sta: Time.parse('2024-01-02T14:00:00Z')) }
      let!(:segment2) { create(:segment, airline: 'S7', origin_iata: 'OVB', destination_iata: 'DME', std: Time.parse('2024-01-02T18:00:00Z'), sta: Time.parse('2024-01-02T22:00:00Z')) } # 4h connection

      it 'does not find the route' do
        result = described_class.call(params)
        expect(result).to be_empty
      end
    end

    context 'when a segment is missing' do
      let!(:permitted_route) { create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: false, transfer_iata_codes: ['OVB']) }
      let!(:segment1) { create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'OVB', std: Time.parse('2024-01-02T10:00:00Z'), sta: Time.parse('2024-01-02T14:00:00Z')) }

      it 'does not find the route' do
        result = described_class.call(params)
        expect(result).to be_empty
      end
    end

    context 'when departure time is outside the window' do
      let!(:permitted_route) { create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true) }
      let!(:segment) { create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'DME', std: Time.parse('2023-12-31T10:00:00Z'), sta: Time.parse('2023-12-31T14:00:00Z')) }

      it 'does not find the route' do
        result = described_class.call(params)
        expect(result).to be_empty
      end
    end

    it 'returns an empty array when no permitted route is found' do
      # No permitted_route created
      result = described_class.call(params)
      expect(result).to be_empty
    end
  end
end
