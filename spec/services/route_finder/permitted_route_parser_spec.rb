require 'rails_helper'

RSpec.describe RouteFinder::PermittedRouteParser do
  describe '.call' do
    let(:origin_iata) { 'UUS' }
    let(:destination_iata) { 'DME' }

    subject { described_class.call(permitted_route) }

    context 'with a direct route only' do
      let(:permitted_route) do
        build(:permitted_route,
              origin_iata: origin_iata,
              destination_iata: destination_iata,
              direct: true,
              transfer_iata_codes: [])
      end

      it 'returns only the direct path' do
        expect(subject).to contain_exactly([origin_iata, destination_iata])
      end
    end

    context 'with transfer routes only' do
      let(:permitted_route) do
        build(:permitted_route,
              origin_iata: origin_iata,
              destination_iata: destination_iata,
              direct: false,
              transfer_iata_codes: ['OVB', 'VVOOVB'])
      end

      it 'returns the single and multi-stop transfer paths' do
        expect(subject).to contain_exactly(
          [origin_iata, 'OVB', destination_iata],
          [origin_iata, 'VVO', 'OVB', destination_iata]
        )
      end
    end

    context 'with both direct and transfer routes' do
      let(:permitted_route) do
        build(:permitted_route,
              origin_iata: origin_iata,
              destination_iata: destination_iata,
              direct: true,
              transfer_iata_codes: ['KHV'])
      end

      it 'returns both direct and transfer paths' do
        expect(subject).to contain_exactly(
          [origin_iata, destination_iata],
          [origin_iata, 'KHV', destination_iata]
        )
      end
    end

    context 'with malformed transfer codes' do
      let(:permitted_route) do
        build(:permitted_route,
              origin_iata: origin_iata,
              destination_iata: destination_iata,
              direct: false,
              transfer_iata_codes: ['OVB', 'VVOOVB', 'IK', ''])
      end

      it 'ignores malformed and empty codes and parses valid ones' do
        expect(subject).to contain_exactly(
          [origin_iata, 'OVB', destination_iata],
          [origin_iata, 'VVO', 'OVB', destination_iata]
        )
      end
    end

    context 'when no routes are permitted' do
      let(:permitted_route) do
        build(:permitted_route,
              origin_iata: origin_iata,
              destination_iata: destination_iata,
              direct: false,
              transfer_iata_codes: [])
      end

      it 'returns an empty array' do
        expect(subject).to be_empty
      end
    end
  end
end
