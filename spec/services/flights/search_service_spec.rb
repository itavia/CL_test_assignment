# frozen_string_literal: true

RSpec.describe Flights::SearchService do
  subject(:result) { described_class.call(flight_params) }

  let(:origin) { "JFK" }
  let(:destination) { "SFO" }
  let(:departure_from) { DateTime.parse("2025-09-01 08:00") }
  let(:departure_to) { DateTime.parse("2025-09-01 20:00") }

  let(:flight_params) do
    {
      origin_iata: origin,
      destination_iata: destination,
      carrier: "AA",
      departure_from: departure_from,
      departure_to: departure_to
    }
  end

  context "when no permitted route exists" do
    it "returns empty array" do
      expect(result).to eq([])
    end
  end

  context "when permitted route exists with transfer flights" do
    before do
      create(:permitted_route, carrier: "AA", origin_iata: origin, destination_iata: destination, direct: false, transfer_iata_codes: [ "LAX" ])
      segment1 = create(:segment, airline: "AA", segment_number: 1, origin_iata: origin, destination_iata: "LAX", std: departure_from, sta: departure_from + 2.hours)
      create(:segment, airline: "AA", segment_number: 2, origin_iata: "LAX", destination_iata: destination, std: segment1.sta + (Flights::Config::MIN_CONNECTION_TIME + 1).minutes, sta: segment1.sta + (Flights::Config::MIN_CONNECTION_TIME + 1 + 180).minutes)
    end

    it { expect(result.first[:origin_iata]).to eq(origin) }
    it { expect(result.first[:destination_iata]).to eq(destination) }
    it { expect(result.first[:segments].size).to eq(2) }
    it { expect(result.first[:segments].map { |s| s[:origin_iata] }).to eq([ origin, "LAX" ]) }
  end

  context "when there are valid and invalid connecting segments based on connection time" do
    before do
      create(:permitted_route, carrier: "AA", origin_iata: origin, destination_iata: destination, direct: false, transfer_iata_codes: [ "LAX" ])
      valid_segment = create(:segment, airline: "AA", segment_number: 4, origin_iata: origin, destination_iata: "LAX", std: departure_from, sta: departure_from + 2.hours)
      create(:segment, airline: "AA", segment_number: 6, origin_iata: "LAX", destination_iata: destination, std: valid_segment.sta + (Flights::Config::MIN_CONNECTION_TIME - 1).minutes, sta: valid_segment.sta + (Flights::Config::MIN_CONNECTION_TIME - 1 + 120).minutes)
      create(:segment, airline: "AA", segment_number: 5, origin_iata: "LAX", destination_iata: destination, std: valid_segment.sta + (Flights::Config::MIN_CONNECTION_TIME + 1).minutes, sta: valid_segment.sta + (Flights::Config::MIN_CONNECTION_TIME + 1 + 180).minutes)
    end

    it { expect(result.size).to eq(1) }
    it { expect(result.first[:segments].map { |s| s[:segment_number] }).to eq([ "4", "5" ]) }
  end
end
