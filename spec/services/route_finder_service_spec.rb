# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RouteFinderService do
  describe '.call' do
    context 'когда разрешенный маршрут не найден' do
      it 'возвращает пустой массив' do
        params = {
          carrier: 'S7',
          origin_iata: 'UUS',
          destination_iata: 'DME',
          departure_from: '2024-01-01',
          departure_to: '2024-01-07'
        }

        result = described_class.call(**params)

        expect(result).to be_empty
      end
    end

    context 'когда есть разрешенный маршрут, но нет доступных сегментов' do
      it 'возвращает пустой массив' do
        create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true)
        params = {
          carrier: 'S7',
          origin_iata: 'UUS',
          destination_iata: 'DME',
          departure_from: '2024-01-01',
          departure_to: '2024-01-07'
        }

        result = described_class.call(**params)

        expect(result).to be_empty
      end
    end

    context 'для прямых перелетов' do
      it 'находит валидный прямой сегмент в указанном диапазоне дат' do
        create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true)
        create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'DME',
                         std: Time.zone.parse('2024-01-02 10:00'), sta: Time.zone.parse('2024-01-02 18:00'))
        params = {
          carrier: 'S7',
          origin_iata: 'UUS',
          destination_iata: 'DME',
          departure_from: '2024-01-01',
          departure_to: '2024-01-07'
        }

        result = described_class.call(**params)

        expect(result.size).to eq(1)
        expect(result.first[:segments].size).to eq(1)
        expect(result.first[:origin_iata]).to eq('UUS')
        expect(result.first[:destination_iata]).to eq('DME')
      end

      it 'не находит сегмент, вылетающий за пределами указанного диапазона дат' do
        create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME', direct: true)
        create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'DME',
                         std: Time.zone.parse('2024-01-08 10:00'), sta: Time.zone.parse('2024-01-08 18:00'))
        params = {
          carrier: 'S7',
          origin_iata: 'UUS',
          destination_iata: 'DME',
          departure_from: '2024-01-01',
          departure_to: '2024-01-07'
        }

        result = described_class.call(**params)

        expect(result).to be_empty
      end
    end

    context 'для перелетов с одной пересадкой' do
      it 'находит маршрут с валидным временем стыковки (стыковка 10 часов)' do
        create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME',
                                 direct: false, transfer_iata_codes: [ 'OVB' ])
        create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'OVB',
                         std: Time.zone.parse('2024-01-03 12:00'), sta: Time.zone.parse('2024-01-03 14:00'))
        create(:segment, airline: 'S7', origin_iata: 'OVB', destination_iata: 'DME',
                         std: Time.zone.parse('2024-01-04 00:00'), sta: Time.zone.parse('2024-01-04 08:00'))
        params = {
          carrier: 'S7',
          origin_iata: 'UUS',
          destination_iata: 'DME',
          departure_from: '2024-01-01',
          departure_to: '2024-01-07'
        }

        result = described_class.call(**params)

        expect(result.size).to eq(1)
        expect(result.first[:segments].size).to eq(2)
      end

      it 'не находит маршрут, если время стыковки слишком короткое (стыковка 4 часа < 8)' do
        create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME',
                                 direct: false, transfer_iata_codes: [ 'OVB' ])
        create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'OVB',
                         std: Time.zone.parse('2024-01-03 12:00'), sta: Time.zone.parse('2024-01-03 14:00'))
        create(:segment, airline: 'S7', origin_iata: 'OVB', destination_iata: 'DME',
                         std: Time.zone.parse('2024-01-03 18:00'), sta: Time.zone.parse('2024-01-03 22:00'))
        params = {
          carrier: 'S7',
          origin_iata: 'UUS',
          destination_iata: 'DME',
          departure_from: '2024-01-01',
          departure_to: '2024-01-07'
        }

        result = described_class.call(**params)

        expect(result).to be_empty
      end
    end

    context 'для перелетов с несколькими пересадками' do
      it 'находит валидный маршрут с двумя стыковками' do
        create(:permitted_route, carrier: 'S7', origin_iata: 'UUS', destination_iata: 'DME',
                                 direct: false, transfer_iata_codes: [ 'VVOOVB' ])
        # UUS -> VVO
        create(:segment, airline: 'S7', origin_iata: 'UUS', destination_iata: 'VVO',
                         std: Time.zone.parse('2024-01-01 06:00'), sta: Time.zone.parse('2024-01-01 08:00'))
        # VVO -> OVB (стыковка 12 часов)
        create(:segment, airline: 'S7', origin_iata: 'VVO', destination_iata: 'OVB',
                         std: Time.zone.parse('2024-01-01 20:00'), sta: Time.zone.parse('2024-01-02 02:00'))
        # OVB -> DME (стыковка 12 часов)
        create(:segment, airline: 'S7', origin_iata: 'OVB', destination_iata: 'DME',
                         std: Time.zone.parse('2024-01-02 14:00'), sta: Time.zone.parse('2024-01-02 18:00'))
        params = {
          carrier: 'S7',
          origin_iata: 'UUS',
          destination_iata: 'DME',
          departure_from: '2024-01-01',
          departure_to: '2024-01-07'
        }

        result = described_class.call(**params)

        expect(result.size).to eq(1)
        expect(result.first[:segments].size).to eq(3)
        expect(result.first[:segments].map { |s| s[:origin_iata] }).to eq([ 'UUS', 'VVO', 'OVB' ])
      end
    end
  end
end
