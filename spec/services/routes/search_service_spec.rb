require 'rails_helper'

RSpec.describe Routes::SearchService, type: :model do
  let(:carrier) { 'S7' }
  let(:origin_iata) { 'UUS' }
  let(:destination_iata) { 'DME' }
  let(:departure_from) { '2024-01-15' }
  let(:departure_to) { '2024-01-20' }
  let(:service) { described_class.new(carrier: carrier, origin_iata: origin_iata, destination_iata: destination_iata, departure_from: departure_from, departure_to: departure_to) }

  subject(:service) { described_class.new(carrier: carrier, origin_iata: origin_iata, destination_iata: destination_iata, departure_from: departure_from, departure_to: departure_to) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:carrier) }
    it { is_expected.to validate_presence_of(:origin_iata) }
    it { is_expected.to validate_presence_of(:destination_iata) }
    it { is_expected.to validate_presence_of(:departure_from) }
    it { is_expected.to validate_presence_of(:departure_to) }

    it { is_expected.to allow_value('UUS').for(:origin_iata) }
    it { is_expected.to allow_value('DME').for(:destination_iata) }
    it { is_expected.not_to allow_value('UU').for(:origin_iata) }
    it { is_expected.not_to allow_value('DM').for(:destination_iata) }
    it { is_expected.not_to allow_value('UUUU').for(:origin_iata) }
    it { is_expected.not_to allow_value('DMEE').for(:destination_iata) }
  end

  describe '#perform' do
    context 'when service is invalid' do
      let(:carrier) { nil }

      it 'returns false' do
        expect(service.perform).to be false
      end
    end

    context 'when no permitted route exists' do
      it 'returns true and does not populate routes' do
        expect(service.perform).to be true
        expect(service.send(:routes)).to be_empty
      end
    end

    context 'when permitted route exists' do
      context 'with direct route' do
        let!(:permitted_route) { create(:permitted_route, carrier: carrier, origin_iata: origin_iata, destination_iata: destination_iata) }
        let!(:segment) { create(:segment, airline: carrier, origin_iata: origin_iata, destination_iata: destination_iata, std: service.departure_from + 1.hour, sta: service.departure_from + 5.hours) }

        it 'returns true and populates routes with segments' do
          expect(service.perform).to be true
          expect(service.send(:routes)).to include([segment])
        end
      end

      context 'with transfer route' do
        let!(:permitted_route) { create(:permitted_route, carrier: carrier, origin_iata: origin_iata, destination_iata: destination_iata, direct: false, transfer_iata_codes: ["ORD"]) }
        let!(:first_segment) { create(:segment, airline: carrier, origin_iata: origin_iata, destination_iata: 'ORD', std: service.departure_from + 1.hour, sta: service.departure_from + 5.hours) }
        let!(:second_segment) { create(:segment, airline: carrier, origin_iata: 'ORD', destination_iata: destination_iata, std: service.departure_from + 15.hours, sta: service.departure_from + 16.hours) }

        it 'returns true' do
          expect(service.perform).to be true
        end

        it 'returns true populates routes with connected segments' do
          expect(service.perform).to be true
          expect(service.send(:routes)).to include([first_segment, second_segment])
        end
      end

      context 'with multiple transfer routes' do
        let!(:permitted_route) { create(:permitted_route, carrier: carrier, origin_iata: origin_iata, destination_iata: destination_iata, direct: false, transfer_iata_codes: ["ORDDFW"]) }
        let!(:first_segment) { create(:segment, airline: carrier, origin_iata: origin_iata, destination_iata: 'ORD', std: service.departure_from + 1.hour, sta: service.departure_from + 5.hours) }
        let!(:second_segment) { create(:segment, airline: carrier, origin_iata: 'ORD', destination_iata: 'DFW', std: service.departure_from + 15.hours, sta: service.departure_from + 17.hours) }
        let!(:third_segment) { create(:segment, airline: carrier, origin_iata: 'DFW', destination_iata: destination_iata, std: service.departure_from + 26.hours, sta: service.departure_from + 31.hours) }

        it 'returns true andpopulates routes with all connected segments' do
          expect(service.perform).to be true
          expect(service.send(:routes)).to include([first_segment, second_segment, third_segment])
        end
      end
    end
  end

  describe '#routes_to_json' do
    context 'with single segments' do
      let!(:permitted_route) { create(:permitted_route, carrier: carrier, origin_iata: origin_iata, destination_iata: destination_iata) }
      let!(:segment1) { create(:segment, airline: carrier, origin_iata: origin_iata, destination_iata: destination_iata, std: service.departure_from + 1.hour, sta: service.departure_from + 5.hours) }
      let!(:segment2) { create(:segment, airline: carrier, origin_iata: origin_iata, destination_iata: destination_iata, std: service.departure_from + 14.hours, sta: service.departure_from + 15.hours) }

      it 'returns routes in JSON format' do
        service.perform
        json_result = service.routes_to_json

        expect(json_result).to be_an(Array)
        expect(json_result.length).to eq(2)

        route = json_result.first
        expect(route[:origin_iata]).to eq(origin_iata)
        expect(route[:destination_iata]).to eq(destination_iata)
        expect(route[:departure_time]).to eq(segment1.std.iso8601(3))
        expect(route[:arrival_time]).to eq(segment1.sta.iso8601(3))

        expect(route[:segments]).to be_an(Array)
        expect(route[:segments].length).to eq(1)

        segment_json = route[:segments].first
        expect(segment_json[:carrier]).to eq(segment1.airline)
        expect(segment_json[:segment_number]).to eq(segment1.segment_number)
        expect(segment_json[:origin_iata]).to eq(segment1.origin_iata)
        expect(segment_json[:destination_iata]).to eq(segment1.destination_iata)
        expect(segment_json[:std]).to eq(segment1.std.iso8601(3))
        expect(segment_json[:sta]).to eq(segment1.sta.iso8601(3))
      end
    end

    context 'with multiple segments' do
      let!(:permitted_route) { create(:permitted_route, carrier: carrier, origin_iata: origin_iata, destination_iata: destination_iata, transfer_iata_codes: ["ORD"]) }
      let!(:segment1) { create(:segment, airline: carrier, origin_iata: origin_iata, destination_iata: 'ORD', std: service.departure_from + 1.hour, sta: service.departure_from + 5.hours) }
      let!(:segment2) { create(:segment, airline: carrier, origin_iata: 'ORD', destination_iata: destination_iata, std: service.departure_from + 14.hours, sta: service.departure_from + 16.hours) }

      it 'returns route with multiple segments' do
        service.perform
        json_result = service.routes_to_json
        
        route = json_result.first

        expect(route[:segments].length).to eq(2)
        expect(route[:departure_time]).to eq(segment1.std.iso8601(3))
        expect(route[:arrival_time]).to eq(segment2.sta.iso8601(3))
      end
    end
  end
end
