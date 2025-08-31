# frozen_string_literal: true

RSpec.describe RoutesQuery do
  let(:flight_params) do
    {
      carrier: 'AA',
      departure_from: DateTime.parse('2025-09-01 08:00'),
      departure_to: DateTime.parse('2025-09-01 20:00'),
      route: [ 'JFK', 'LAX', 'SFO' ]
    }
  end

  describe '.call' do
    subject(:result) { described_class.call(flight_params) }

    it 'is an array containing SQL string' do
      sql, = result
      expect(sql).to be_a(String)
    end

    it 'includes SELECT in the SQL' do
      sql, = result
      expect(sql).to include('SELECT')
    end

    it 'returns correct query parameters' do
      _, params = result
      expect(params).to eq([ flight_params[:carrier], flight_params[:departure_from], flight_params[:departure_to] ])
    end

    it { expect(result.first).to include('segments s1') }
    it { expect(result.first).to include('JOIN segments s2') }
    it { expect(result.first).to include('JFK') }
    it { expect(result.first).to include('LAX') }
    it { expect(result.first).to include('SFO') }
    it { expect(result.first).to include('UNION ALL') }
  end
end
