# frozen_string_literal: true

# RouteFinder — строит все допустимые маршруты для заданных параметров ТЗ.
#
# Вход:
#   carrier: "S7"
#   origin_iata: "UUS"
#   destination_iata: "DME"
#   departure_from: Time (UTC)
#   departure_to:   Time (UTC)
#   max_transfers: Integer | nil  (0 => только прямые; 1 => не более одной пересадки; nil => без ограничения)
#
# Правила:
# - Берём разрешённые маршруты (PermittedRoute) для carrier+origin+destination.
# - direct: true — вариант без пересадок.
# - transfer_iata_codes — элементы "OVB" или слитные "VVOOVB"; режем по 3.
# - Окно стыковок строго по ТЗ: 8..48 часов (включительно).
# - Выход: массив маршрутов; ключевые поля из ТЗ + вспомогательные поля для твоих реквест-спеков.

class RouteFinder
  MIN_CONNECTION_TIME = 480   # minutes (8h)
  MAX_CONNECTION_TIME = 2880  # minutes (48h)

  ResultSegment = Struct.new(:carrier, :segment_number, :origin_iata, :destination_iata, :std, :sta, keyword_init: true)

  def initialize(carrier:, origin_iata:, destination_iata:, departure_from:, departure_to:, max_transfers: nil)
    @carrier        = carrier.to_s.upcase
    @origin_iata    = origin_iata.to_s.upcase
    @destination    = destination_iata.to_s.upcase
    @departure_from = departure_from
    @departure_to   = departure_to
    @max_transfers  = max_transfers
  end

  def call
    prs = PermittedRoute.where(
      carrier: @carrier,
      origin_iata: @origin_iata,
      destination_iata: @destination
    )
    return [] if prs.blank?

    itineraries = []

    prs.find_each do |pr|
      # 1) прямые
      if pr.direct?
        itineraries.concat build_itineraries_for_chain([@origin_iata, @destination])
      end

      # 2) пересадки
      Array(pr.transfer_iata_codes).each do |code|
        hops = split_iata_chain(code)
        next if hops.empty?

        # Ограничение по количеству пересадок
        if !@max_transfers.nil?
          next if @max_transfers == 0
          next if hops.size > @max_transfers
        end

        chain = [@origin_iata, *hops, @destination]
        itineraries.concat build_itineraries_for_chain(chain)
      end
    end

    itineraries
  end

  private

  # "VVO" -> ["VVO"], "VVOOVB" -> ["VVO","OVB"]
  def split_iata_chain(code)
    s = code.to_s.strip.upcase
    return [] if s.empty?
    raise ArgumentError, "Invalid transfer chain length" unless (s.length % 3).zero?
    s.scan(/.{3}/)
  end

  # Для цепочки [A, B, C, D] строим комбинации сегментов A->B, B->C, C->D
  def build_itineraries_for_chain(chain)
    legs = chain.each_cons(2).to_a # [[A,B],[B,C],[C,D]]

    # Первое плечо — ограничиваем окном вылета
    first_leg_segments = find_segments(legs.first[0], legs.first[1], limit_by_window: true)
    return [] if first_leg_segments.empty?

    results = []
    stack = []
    dfs_build(chain, legs, 0, first_leg_segments, stack, results)
    results
  end

  def dfs_build(chain, legs, leg_index, candidates, stack, results)
    candidates.each do |seg|
      stack.push(seg)

      if leg_index == legs.size - 1
        results << build_result(stack)
      else
        next_origin, next_dest = legs[leg_index + 1]
        next_candidates = find_segments(next_origin, next_dest, after_arrival: seg.sta)
        dfs_build(chain, legs, leg_index + 1, next_candidates, stack, results)
      end

      stack.pop
    end
  end

  def build_result(stack)
    # Берём начало/конец маршрута из стека сегментов
    route_origin = stack.first.origin_iata
    route_dest   = stack.last.destination_iata

    segments_payload = stack.map do |s|
      {
        "carrier"          => s.carrier,
        "segment_number"   => s.segment_number,
        "origin_iata"      => s.origin_iata,
        "destination_iata" => s.destination_iata,
        "std"              => s.std.iso8601(3),
        "sta"              => s.sta.iso8601(3)
      }
    end

    payload = {
      "origin_iata"      => route_origin,
      "destination_iata" => route_dest,
      "departure_time"   => stack.first.std.iso8601(3),
      "arrival_time"     => stack.last.sta.iso8601(3),
      "segments"         => segments_payload
    }

    # Доп. поля для твоих реквест-спеков (не противоречат ТЗ)
    payload["type"] = (stack.size == 1 ? "direct" : "transfer")
    payload["legs"] = segments_payload

    if stack.size == 2
      # Ровно одна пересадка
      payload["transfer_airport"] = stack.first.destination_iata
      payload["connection_minutes"] = ((stack.last.std - stack.first.sta) / 60).to_i
    end

    payload
  end

  # Ищем сегменты для плеча origin->dest
  # - limit_by_window: для первого плеча std ∈ [@departure_from, @departure_to]
  # - after_arrival:   для следующих — std в окне стыковки (8..48 ч) от sta предыдущего
  def find_segments(origin, dest, limit_by_window: false, after_arrival: nil)
    scope = Segment.where(
      airline: @carrier,
      origin_iata: origin,
      destination_iata: dest
    ).order(:std)

    scope = scope.where(std: @departure_from..@departure_to) if limit_by_window

    records = scope.to_a

    if after_arrival
      records.select! do |s|
        minutes = (s.std - after_arrival) / 60.0
        minutes >= MIN_CONNECTION_TIME && minutes <= MAX_CONNECTION_TIME
      end
    end

    # Оборачиваем в ResultSegment (чтобы гарантированно был carrier в элементе)
    records.map do |s|
      ResultSegment.new(
        carrier: @carrier,
        segment_number: s.segment_number,
        origin_iata: s.origin_iata,
        destination_iata: s.destination_iata,
        std: s.std,
        sta: s.sta
      )
    end
  end
end
