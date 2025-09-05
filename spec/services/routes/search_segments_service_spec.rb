require 'rails_helper'

RSpec.describe Routes::SearchSegmentsService do
  let(:carrier) { 'S7' }
  let(:departure_from) { 1.day.from_now }
  let(:departure_to) { 5.days.from_now }
  let(:service) { described_class.new(carrier: carrier, departure_from: departure_from, departure_to: departure_to, segment_paths: segment_paths) }

  describe '#perform' do
    context 'with single segment path' do
      let(:segment_paths) { [['UUS', 'DME']] }

      context 'when segments exist' do
        let!(:segment1) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: departure_from + 1.hour, sta: departure_from + 5.hours) }
        let!(:segment2) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: departure_from + 2.hours, sta: departure_from + 6.hours) }
        let!(:segment3) { create(:segment, airline: 'AE', origin_iata: 'UUS', destination_iata: 'DME', std: departure_from + 1.hour, sta: departure_from + 5.hours) }

        it 'returns segments for the specified carrier and path' do
          service.perform
          expect(service.segments).to include([segment1], [segment2])
          expect(service.segments).not_to include([segment3])
        end

        context 'when segments are not in departure time range' do
          let!(:early_segment) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: departure_from - 1.hour, sta: departure_from + 3.hours) }
          let!(:late_segment) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: departure_to + 1.hour, sta: departure_to + 5.hours) }

          it 'returns filtered segments' do
            service.perform
            expect(service.segments).not_to include([early_segment])
            expect(service.segments).not_to include([late_segment])
          end
        end

        context 'when segments are not before departure time' do
          let!(:late_arrival_segment) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: departure_from + 1.hour, sta: departure_to + 1.hour) }
          
          it 'returns filtered segments' do
            service.perform
            expect(service.segments).not_to include([late_arrival_segment])
          end
        end
      end

      context 'when no segments exist' do
        it 'returns empty array' do
          service.perform
          expect(service.segments).to eq([])
        end
      end
    end

    context 'with multiple segment paths' do
      let(:segment_paths) { [['UUS', 'DME'], ['DME', 'LED']] }
      let(:first_departure) { departure_from + 1.hour }
      let(:first_arrival) { departure_from + 5.hours }
      let(:second_departure) { first_arrival + 9.hours }
      let(:second_arrival) { second_departure + 1.hour }

      context 'when valid connections exist' do
        let!(:first_segment) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: first_departure, sta: first_arrival) }
        let!(:second_segment) { create(:segment, airline: carrier, origin_iata: 'DME', destination_iata: 'LED', std: second_departure, sta: second_arrival) }

        it 'returns connected segments' do
          service.perform
          expect(service.segments).to include([first_segment, second_segment])
        end

        context 'with too early connection' do
          let!(:too_early_second) { create(:segment, airline: carrier, origin_iata: 'DME', destination_iata: 'LED', std: first_arrival + 1.hour, sta: first_arrival + 2.hours) }

          it 'considers minimum connection time' do
            service.perform
            expect(service.segments).not_to include([first_segment, too_early_second])
          end
        end

        context 'with too late connection' do
          let!(:too_late_second) { create(:segment, airline: carrier, origin_iata: 'DME', destination_iata: 'LED', std: first_arrival + 50.hours, sta: first_arrival + 51.hours) }

          it 'considers maximum connection time' do
            service.perform
            expect(service.segments).not_to include([first_segment, too_late_second])
          end
        end
      end

      context 'when no valid connections exist' do
        let!(:first_segment) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: first_departure, sta: first_arrival) }
        let!(:second_segment) { create(:segment, airline: carrier, origin_iata: 'DME', destination_iata: 'LED', std: first_arrival + 1.hour, sta: first_arrival + 2.hours) }

        it 'returns empty array' do
          service.perform
          expect(service.segments).to eq([])
        end
      end

      context 'when 2 segments suit one path' do
        let!(:first_segment) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: first_departure, sta: first_arrival) }
        let!(:second_segment1) { create(:segment, airline: carrier, origin_iata: 'DME', destination_iata: 'LED', std: second_departure, sta: second_arrival) }
        let!(:second_segment2) { create(:segment, airline: carrier, origin_iata: 'DME', destination_iata: 'LED', std: second_departure + 1.hour, sta: second_arrival + 1.hour) }

        it 'returns both valid connections' do
          service.perform
          expect(service.segments).to include([first_segment, second_segment1])
          expect(service.segments).to include([first_segment, second_segment2])
        end
      end
    end

    context 'with three segment paths' do
      let(:segment_paths) { [['UUS', 'DME'], ['DME', 'LED'], ['LED', 'SVO']] }
      let(:first_departure) { departure_from + 1.hour }
      let(:first_arrival) { departure_from + 5.hours }
      let(:second_departure) { first_arrival + 8.hours }
      let(:second_arrival) { second_departure + 1.hour }
      let(:third_departure) { second_arrival + 8.hours }
      let(:third_arrival) { third_departure + 1.hour }

      context 'when valid connections exist' do
        let!(:first_segment) { create(:segment, airline: carrier, origin_iata: 'UUS', destination_iata: 'DME', std: first_departure, sta: first_arrival) }
        let!(:second_segment) { create(:segment, airline: carrier, origin_iata: 'DME', destination_iata: 'LED', std: second_departure, sta: second_arrival) }
        let!(:third_segment) { create(:segment, airline: carrier, origin_iata: 'LED', destination_iata: 'SVO', std: third_departure, sta: third_arrival) }

        it 'returns all three connected segments' do
          service.perform
          expect(service.segments).to include([first_segment, second_segment, third_segment])
        end
      end
    end
  end
end
