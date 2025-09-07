require 'rails_helper'

RSpec.describe RouteFinder::ItineraryBuilder do
  describe '.call' do
    let(:carrier) { 'S7' }
    let(:departure_from) { '2024-01-01' }
    let(:departure_to) { '2024-01-02' }

    # Time constants for convenience
    let(:t0) { Time.zone.parse('2024-01-01T10:00:00Z') }

    # Segments
    let!(:uus_ovb) { create(:segment, origin_iata: 'UUS', destination_iata: 'OVB', std: t0, sta: t0 + 4.hours) }
    # Valid connection: 10 hours after UUS-OVB lands
    let!(:ovb_dme_valid) { create(:segment, origin_iata: 'OVB', destination_iata: 'DME', std: t0 + 14.hours, sta: t0 + 18.hours) }
    # Too short connection: 2 hours after UUS-OVB lands
    let!(:ovb_dme_short) { create(:segment, origin_iata: 'OVB', destination_iata: 'DME', std: t0 + 6.hours, sta: t0 + 10.hours) }
    # Too long connection: 50 hours after UUS-OVB lands
    let!(:ovb_dme_long) { create(:segment, origin_iata: 'OVB', destination_iata: 'DME', std: t0 + 54.hours, sta: t0 + 58.hours) }
    # A segment that doesn't fit the path
    let!(:khv_dme) { create(:segment, origin_iata: 'KHV', destination_iata: 'DME', std: t0, sta: t0 + 4.hours) }
    # A direct flight segment for a different test
    let!(:uus_dme_direct) { create(:segment, origin_iata: 'UUS', destination_iata: 'DME', std: t0, sta: t0 + 8.hours) }

    let(:all_segments) { [uus_ovb, ovb_dme_valid, ovb_dme_short, ovb_dme_long, khv_dme, uus_dme_direct] }
    let(:segments_by_origin) { all_segments.group_by(&:origin_iata) }

    subject do
      described_class.call(
        blueprint_path: blueprint_path,
        segments_by_origin: segments_by_origin,
        departure_from: departure_from,
        departure_to: departure_to
      )
    end

    context 'for a direct path' do
      let(:blueprint_path) { ['UUS', 'DME'] }

      it 'finds the direct flight itinerary' do
        expect(subject.count).to eq(1)
        expect(subject.first).to contain_exactly(uus_dme_direct)
      end

      context 'when the flight is outside the date range' do
        let(:departure_from) { '2024-01-03' }
        it { is_expected.to be_empty }
      end
    end

    context 'for a path with one transfer' do
      let(:blueprint_path) { ['UUS', 'OVB', 'DME'] }

      it 'finds the itinerary with a valid connection time' do
        expect(subject.count).to eq(1)
        expect(subject.first).to contain_exactly(uus_ovb, ovb_dme_valid)
      end
    end

    context 'when no valid itineraries can be built' do
      let(:blueprint_path) { ['UUS', 'KHV', 'DME'] } # UUS->KHV segment doesn't exist

      it 'returns an empty array' do
        expect(subject).to be_empty
      end
    end
  end
end
