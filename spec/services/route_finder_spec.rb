# frozen_string_literal: true
require "rails_helper"

RSpec.describe RouteFinder, type: :service do
  let(:carrier) { "S7" }
  let(:origin)  { "UUS" }
  let(:dest)    { "DME" }

  let(:from) { Time.zone.parse("2024-01-01 00:00:00 UTC") }
  let(:to)   { Time.zone.parse("2024-01-07 23:59:59 UTC") }

  before do
    # Разрешённые маршруты:
    PermittedRoute.create!(
      carrier: carrier, origin_iata: origin, destination_iata: dest,
      direct: true, transfer_iata_codes: ["OVB", "VVOOVB"]
    )

    # Сегменты для прямого
    Segment.create!(
      airline: carrier, segment_number: "1001",
      origin_iata: origin, destination_iata: dest,
      std: Time.zone.parse("2024-01-02 08:00:00 UTC"),
      sta: Time.zone.parse("2024-01-02 12:00:00 UTC")
    )

    # Сегменты для UUS->VVO->OVB->DME
    Segment.create!(
      airline: carrier, segment_number: "2001",
      origin_iata: origin, destination_iata: "VVO",
      std: Time.zone.parse("2024-01-01 05:45:00 UTC"),
      sta: Time.zone.parse("2024-01-01 07:40:00 UTC")
    )
    Segment.create!(
      airline: carrier, segment_number: "2002",
      origin_iata: "VVO", destination_iata: "OVB",
      std: Time.zone.parse("2024-01-02 00:30:00 UTC"), # стыковка > 8ч
      sta: Time.zone.parse("2024-01-02 05:30:00 UTC")
    )
    Segment.create!(
      airline: carrier, segment_number: "2003",
      origin_iata: "OVB", destination_iata: dest,
      std: Time.zone.parse("2024-01-02 14:00:00 UTC"),
      sta: Time.zone.parse("2024-01-02 18:05:00 UTC")
    )

    # Сегменты для UUS->OVB->DME
    Segment.create!(
      airline: carrier, segment_number: "3001",
      origin_iata: origin, destination_iata: "OVB",
      std: Time.zone.parse("2024-01-01 10:00:00 UTC"),
      sta: Time.zone.parse("2024-01-01 12:00:00 UTC")
    )
    Segment.create!(
      airline: carrier, segment_number: "3002",
      origin_iata: "OVB", destination_iata: dest,
      std: Time.zone.parse("2024-01-03 00:30:00 UTC"), # стыковка > 8ч и < 48ч
      sta: Time.zone.parse("2024-01-03 06:30:00 UTC")
    )
  end

  it "builds direct route when direct segments exist" do
    result = described_class.new(
      carrier: carrier, origin_iata: origin, destination_iata: dest,
      departure_from: from, departure_to: to
    ).call

    direct = result.find { |r| r["segments"].size == 1 }
    expect(direct).to be_present
    expect(direct["segments"].first["segment_number"]).to eq("1001")
  end

  it "builds multi-transfer routes from concatenated transfer codes" do
    result = described_class.new(
      carrier: carrier, origin_iata: origin, destination_iata: dest,
      departure_from: from, departure_to: to
    ).call

    multi = result.select { |r| r["segments"].size == 3 }
    expect(multi).not_to be_empty

    example = multi.find { |r|
      r["segments"].map { |s| [s["origin_iata"], s["destination_iata"]] } ==
        [["UUS","VVO"],["VVO","OVB"],["OVB","DME"]]
    }
    expect(example).to be_present
  end

  it "filters routes by connection window 8h..48h" do
    # Добавим заведомо плохой сегмент с маленькой стыковкой
    Segment.create!(
      airline: carrier, segment_number: "BAD1",
      origin_iata: "VVO", destination_iata: "OVB",
      std: Time.zone.parse("2024-01-01 08:00:00 UTC"), # 20 минут стыковка => < 8 часов
      sta: Time.zone.parse("2024-01-01 13:00:00 UTC")
    )

    result = described_class.new(
      carrier: carrier, origin_iata: origin, destination_iata: dest,
      departure_from: from, departure_to: to
    ).call

    # Проверяем, что BAD1 не попал ни в один маршрут
    expect(result.flat_map { |r| r["segments"] }.map { |s| s["segment_number"] }).not_to include("BAD1")
  end

  it "returns empty array if no segments fit" do
    result = described_class.new(
      carrier: "XX", origin_iata: origin, destination_iata: dest,
      departure_from: from, departure_to: to
    ).call

    expect(result).to eq([])
  end
end
