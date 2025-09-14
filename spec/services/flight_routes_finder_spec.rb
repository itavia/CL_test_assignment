require "rails_helper"

RSpec.describe FlightRoutesFinder, type: :service do
  let(:carrier) { "S7" }
  let(:origin_iata) { "UUS" }
  let(:destination_iata) { "DME" }
  let(:departure_from) { "2024-01-01" }
  let(:departure_to) { "2024-01-07" }

  before do
    create(:permitted_route,
           carrier: carrier,
           origin_iata: origin_iata,
           destination_iata: destination_iata,
           direct: true,
           transfer_iata_codes: [ "VVOOVB" ])

    # VALID SEGMENTS

    # direct flight
    create(:segment,
           airline: carrier,
           segment_number: "DIRECT",
           origin_iata: "UUS",
           destination_iata: "DME",
           std: Time.utc(2024, 1, 1, 8, 0),
           sta: Time.utc(2024, 1, 1, 16, 0))

    # UUS - VVO
    create(:segment,
           airline: carrier,
           segment_number: "UUS_VVO",
           origin_iata: "UUS",
           destination_iata: "VVO",
           std: Time.utc(2024, 1, 1, 5, 0),
           sta: Time.utc(2024, 1, 1, 7, 0))

    # VVO - OVB valid flight 13h
    create(:segment,
           airline: carrier,
           segment_number: "VVO_OVB",
           origin_iata: "VVO",
           destination_iata: "OVB",
           std: Time.utc(2024, 1, 1, 20, 0),
           sta: Time.utc(2024, 1, 2, 2, 0))

    # OVB - DME
    create(:segment,
           airline: carrier,
           segment_number: "OVB_DME",
           origin_iata: "OVB",
           destination_iata: "DME",
           std: Time.utc(2024, 1, 2, 13, 0),
           sta: Time.utc(2024, 1, 2, 17, 0))

    # INVALID SEGMENTS

    # before departure_from
    create(:segment,
           airline: carrier,
           segment_number: "TOOEARLY",
           origin_iata: "UUS",
           destination_iata: "VVO",
           std: Time.utc(2023, 12, 31, 23, 0),
           sta: Time.utc(2024, 1, 1, 1, 0))

    # after departure_to
    create(:segment,
           airline: carrier,
           segment_number: "TOOLATE_RANGE",
           origin_iata: "VVO",
           destination_iata: "OVB",
           std: Time.utc(2024, 1, 10, 12, 0),
           sta: Time.utc(2024, 1, 10, 15, 0))

    # transfer time < 8h
    create(:segment,
           airline: carrier,
           segment_number: "TOOFAST",
           origin_iata: "VVO",
           destination_iata: "OVB",
           std: Time.utc(2024, 1, 1, 7, 30),
           sta: Time.utc(2024, 1, 1, 9, 0))

    # transfer time > 48h
    create(:segment,
           airline: carrier,
           segment_number: "TOOLONG",
           origin_iata: "VVO",
           destination_iata: "OVB",
           std: Time.utc(2024, 1, 4, 9, 0),
           sta: Time.utc(2024, 1, 4, 13, 0))

    # UUS - VVO - OVB - KJA doesn't arrive in DME
    create(:segment,
           airline: carrier,
           segment_number: "VVO_KJA",
           origin_iata: "OVB",
           destination_iata: "KJA",
           std: Time.utc(2024, 1, 2, 12, 0),
           sta: Time.utc(2024, 1, 2, 15, 0))

    # UUS - KHV - DME through another airport
    create(:segment,
           airline: carrier,
           segment_number: "UUS_KHV",
           origin_iata: "UUS",
           destination_iata: "KHV",
           std: Time.utc(2024, 1, 1, 9, 0),
           sta: Time.utc(2024, 1, 1, 12, 0))

    create(:segment,
           airline: carrier,
           segment_number: "KHV_DME",
           origin_iata: "KHV",
           destination_iata: "DME",
           std: Time.utc(2024, 1, 1, 20, 0),
           sta: Time.utc(2024, 1, 1, 23, 0))
  end

  let(:result) do
    described_class.new(
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata,
      departure_from: departure_from,
      departure_to: departure_to
    ).call
  end

  it "returns direct route if direct = true" do
    expect(result.any? { |r| r[:segments].size == 1 }).to be true
  end

  it "doesn't return direct route if direct = false" do
    PermittedRoute.delete_all
    create(:permitted_route,
           carrier: carrier,
           origin_iata: origin_iata,
           destination_iata: destination_iata,
           direct: false,
           transfer_iata_codes: [ "VVOOVB" ])

    new_result = described_class.new(
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata,
      departure_from: departure_from,
      departure_to: departure_to
    ).call

    expect(new_result.any? { |r| r[:segments].size == 1 }).to be false
  end

  it "returns the route with transfers" do
    expect(result.any? { |r| r[:segments].size == 3 }).to be true
  end

  it "without routes with transfers < MIN_CONNECTION_TIME" do
    segment_numbers = result.flat_map { |r| r[:segments].map { |s| s[:segment_number] } }
    expect(segment_numbers).not_to include("TOOFAST")
  end

  it "without routes with transfers > MAX_CONNECTION_TIME" do
    segment_numbers = result.flat_map { |r| r[:segments].map { |s| s[:segment_number] } }
    expect(segment_numbers).not_to include("TOOLONG")
  end

  it "ignores segments outside the required date" do
    segment_numbers = result.flat_map { |r| r[:segments].map { |s| s[:segment_number] } }
    expect(segment_numbers).not_to include("TOOEARLY", "TOOLATE_RANGE")
  end

  it "does not return a route that goes to another airport (not DME)" do
    segment_numbers = result.flat_map { |r| r[:segments].map { |s| s[:segment_number] } }
    expect(segment_numbers).not_to include("VVO_KJA")
  end

  it "does not return a route ending in DME but through a prohibited airport" do
    airports_paths = result.map { |r| r[:segments].map { |s| s[:origin_iata] } + [ r[:segments].last[:destination_iata] ] }
    invalid_path = [ "UUS", "KHV", "DME" ]
    expect(airports_paths).not_to include(invalid_path)
  end

  it "returns an empty array if there are no allowed routes" do
    PermittedRoute.delete_all
    new_result = described_class.new(
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata,
      departure_from: departure_from,
      departure_to: departure_to
    ).call
    expect(new_result).to eq([])
  end

  it "returns an empty array if there are no segments" do
    Segment.delete_all
    new_result = described_class.new(
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata,
      departure_from: departure_from,
      departure_to: departure_to
    ).call
    expect(new_result).to eq([])
  end

  it "returns an empty array for a route without segments (UUS - NOZ)" do
    new_result = described_class.new(
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: "NOZ",
      departure_from: departure_from,
      departure_to: departure_to
    ).call
    expect(new_result).to eq([])
  end
end
