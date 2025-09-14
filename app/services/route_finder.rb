# frozen_string_literal: true

# RouteFinder — строит все допустимые маршруты для заданных параметров ТЗ.
#
# Вход:
#   carrier: "S7"
#   origin_iata: "UUS"
#   destination_iata: "DME"
#   departure_from: Time
#   departure_to:   Time
#
# Правила:
# - Берём разрешённые маршруты (PermittedRoute) для carrier+origin+destination
# - Учитываем direct: true (маршрут без пересадок)
# - Учитываем transfer_iata_codes:
#     * элемент массива может быть обычным "OVB" (одна пересадка)
#     * или слитной строкой "VVOOVB" (две пересадки) — режем по 3 символа
# - Для каждой цепочки точек ищем сегменты в таблице Segment (по carrier/airline)
# - Проверяем окно стыковок для каждой стыки:
#     MIN_CONNECTION_TIME = 480 мин (8ч)
#     MAX_CONNECTION_TIME = 2880 мин (48ч)
# - Возвращаем массив маршрутов в формате ТЗ
#
class RouteFinder
  MIN_CONNECTION_TIME = 480   # minutes (8h)
  MAX_CONNECTION_TIME = 2880  # minutes (48h)

  ResultSegment = Struct.new(:carrier, :segment_number, :origin_iata, :destination_iata, :std, :sta, keyword_init: true)

  def initialize(carrier:, origin_iata:, destination_iata:, departure_from:, departure_to:)
    @carrier        = carrier.to_s.upcase
    @origin_iata    = origin_iata.to_s.upcase[0, 3]
    @destination    = destination_iata.to_s.upcase[0, 3]
    @departure_from = departure_from
    @departure_to   = departure_to
  end

  def call
    permitted_routes = PermittedRoute.where(
      carrier: @carrier,
      origin_iata: @origin_iata,
      destination_iata: @destination
    )

    return [] if permitted_routes.blank?

    itineraries = []

    permitted_routes.find_each do |pr|
      # 1) прямой вариант
      if pr.direct?
        chains = [[@origin_iata, @destination]]
        itineraries.concat find_itineraries_for_chains(chains)
      end

      # 2) варианты с пересадками
      Array(pr.transfer_iata_codes).each do |code|
        # "OVB" => ["OVB"]
        # "VVOOVB" => ["VVO","OVB"]
        hops = split_iata_chain(code)

        next if hops.empty?

        chain = [@origin_iata, *hops, @destination]
        itineraries.concat find_itineraries_for_chains([chain])
      end
    end

    itineraries
  end

  private

  # "VVO" -> ["VVO"]
  # "VVOOVB" -> ["VVO","OVB"]
  # "ABCDEF" -> ["ABC","DEF"] (если кратно 3)
  def split_iata_chain(raw)
    s = raw.to_s.upcase.gsub(/[^A-Z]/, '')
    return [] if s.blank?
    return [s] if s.length == 3

    return [] unless (s.length % 3).zero?

    s.scan(/.{3}/)
  end

  # Для каждой цепочки [A, B, C, D] строим все комбинации сегментов A->B, B->C, C->D
  def find_itineraries_for_chains(chains)
    chains.flat_map { |chain| build_itineraries_for_chain(chain) }
  end

  def build_itineraries_for_chain(chain)
    legs = chain.each_cons(2).to_a # [[A,B],[B,C],[C,D]]

    # Для первого плеча ограничиваем std окном departure_from..departure_to
    first_leg_segments = find_segments(legs.first[0], legs.first[1], limit_by_window: true)

    return [] if first_leg_segments.empty?

    # Дальше бэктрекинг
    results = []

    stack = []
    dfs_build(legs, 0, first_leg_segments, stack, results)

    results
  end

  def dfs_build(legs, leg_index, candidate_segments, stack, results)
    candidate_segments.each do |seg|
      stack.push(seg)

      if leg_index == legs.size - 1
        # последний сегмент собран — проверим и добавим итог
        results << build_result(stack)
      else
        next_origin, next_dest = legs[leg_index + 1]

        next_candidates = find_segments(next_origin, next_dest, after_arrival: seg.sta)
        dfs_build(legs, leg_index + 1, next_candidates, stack, results)
      end

      stack.pop
    end
  end

  def build_result(stack)
    {
      "origin_iata"      => stack.first.origin_iata,
      "destination_iata" => stack.last.destination_iata,
      "departure_time"   => stack.first.std.iso8601(3),
      "arrival_time"     => stack.last.sta.iso8601(3),
      "segments"         => stack.map { |s|
        {
          "carrier"         => s.carrier,
          "segment_number"  => s.segment_number,
          "origin_iata"     => s.origin_iata,
          "destination_iata"=> s.destination_iata,
          "std"             => s.std.iso8601(3),
          "sta"             => s.sta.iso8601(3)
        }
      }
    }
  end

  # Ищем сегменты для плеча origin->dest
  # - limit_by_window: для первого плеча ограничение std ∈ [@departure_from, @departure_to]
  # - after_arrival:   для последующих плеч — std в окне стыковки относительно sta предыдущего сегмента
  def find_segments(origin, dest, limit_by_window: false, after_arrival: nil)
    scope = Segment.where(
      airline: @carrier,
      origin_iata: origin,
      destination_iata: dest
    )

    if limit_by_window
      scope = scope.where(std: @departure_from..@departure_to)
    end

    segments = scope.order(:std).to_a

    if after_arrival
      segments.select! do |s|
        conn_min = ((s.std - after_arrival) / 60.0)
        conn_min >= MIN_CONNECTION_TIME && conn_min <= MAX_CONNECTION_TIME
      end
    end

    segments.map do |s|
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
