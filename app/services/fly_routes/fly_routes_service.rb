module FlyRoutes
  ResponseObject = Struct.new(:origin_iata, :destination_iata, :departure_time, :arrival_time, :segments)

  MIN_CONNECTION_TIME = 480 # minimum connection time
  MAX_CONNECTION_TIME = 2880 # maximum connection time

  class FlyRoutesService < Dry::Operation
    def call(params)
      # Роуты для маршрута
      permitted_routes = step get_permitted_routes(params)

      # Индексы сегментов роутов
      iata_segment_indices = step make_segments_indices(permitted_routes)

      # Получаем подходящие сегменты
      segments_relation = step get_segments(iata_segment_indices, params)

      # Создаем маппинг индексов сегментов на сегменты
      mapped_segments = step make_mapped_segments(segments_relation)

      # Создаем пути по индексам
      paths = step make_paths(permitted_routes)

      # Создаем роуты из сегментов
      routes = step make_routes(paths, mapped_segments)

      # Создаем объект ответа
      step make_response_object(routes)
    end

    private

    # В этом методе получаются возможные роуты для маршрута
    # Как ограничения используются: Перевозчик, аэропорт вылета, аэропорт прилета
    # Исходим из того что может быть получено несколько маршрутов
    def get_permitted_routes(params)
      permitted_routes = PermittedRoute.where(params.slice(:carrier, :origin_iata, :destination_iata))

      Success(permitted_routes)
    end

    # В этом методе получается массив сегментов для пути перелета
    # Для получения массива сегментов используются роуте полученные на шаге get_permitted_routes
    # На выходе получается массив сегментов для перелета,
    # который будет в дальнейшеи использоваться для поиска подходящих сегментов и создания маппинга индексов на сегменты
    # Пример:
    # [["UUS", "DME"],
    #  ["UUS", "OVB"],
    #  ["OVB", "DME"],
    #  ["UUS", "KHV"],
    #  ["KHV", "DME"],
    #  ["UUS", "IKT"],
    #  ["IKT", "DME"],
    #  ["UUS", "VVO"],
    #  ["VVO", "OVB"],
    #  ["OVB", "DME"]]
    def make_segments_indices(permitted_routes)
      iata_segment_indices = permitted_routes.each_with_object([]) do |route, result|
        result << [ route.origin_iata, route.destination_iata ] if route.direct

        route.transfer_iata_codes.each_with_object(result) do |raw_codes, result|
          result.push(*raw_codes.scan(/.{3}/).push(route.destination_iata).unshift(route.origin_iata).each_cons(2).to_a)
        end
      end

      Success(iata_segment_indices)
    end

    # Получаем сегменты которые подходят по ряду параметров (airline, std, origin, destination) для построения маршрутов
    def get_segments(iata_segment_indices, params)
      first_routes = iata_segment_indices.shift

      segments_relation = Segment.where(airline: params[:carrier], std: params[:departure_from]..params[:departure_to], origin_iata: first_routes.first, destination_iata: first_routes.last)

      segments = iata_segment_indices.inject(segments_relation) do |relation, route|
        relation.or(Segment.where(airline: params[:carrier], std: params[:departure_from].., origin_iata: route.first, destination_iata: route.last))
      end

      Success(segments)
    end

    # Создаем маппинг индексов сегментов на сегменты
    # Пример:
    # UUDIKT -> [Segment(...), Segment(...)]
    def make_mapped_segments(segments)
      mapped_segments = segments.reduce({}) do |result, segment|
        path_key = "#{segment.origin_iata}#{segment.destination_iata}"
        result[path_key] ||= []
        result[path_key] << segment

        result
      end

      Success(mapped_segments)
    end

    # Создаем пути из индексов
    # Далее будет использоваться для построения конечных путей
    # Пример: [["UUS", "DME"],
    #          ["UUS", "OVB", "DME"],
    #          ["UUS", "KHV", "DME"],
    #          ["UUS", "IKT", "DME"],
    #          ["UUS", "VVO", "OVB", "DME"]]
    def make_paths(iata_routes)
      paths = iata_routes.each_with_object([]) do |route, result|
        result << [ route.origin_iata, route.destination_iata ] if route.direct

        route.transfer_iata_codes.each do |raw_codes|
          result.push(raw_codes.scan(/.{3}/).push(route.destination_iata).unshift(route.origin_iata).to_a)
        end

        result
      end

      Success(paths)
    end

    # Составляем возможные маршруты
    def make_routes(iata_routes, mapped_segments)
      res = iata_routes.each_with_object([]) do |path, paths_result|
        # Получаем сегменты пути
        indexed_path = path.each_cons(2).map(&:join)

        first_segment = indexed_path.shift

        next unless mapped_segments[first_segment]
        accepted_segments = mapped_segments[first_segment].map! { |v| [ v ] }

        # FIX: Проверяем что они подходят по параметрам

        r = indexed_path.inject(accepted_segments) do |created_paths, segment_name|
          next_accepted_segments = mapped_segments[segment_name]

          next unless next_accepted_segments
          r1 = []

          created_paths.each do |one_created_path|
            next_accepted_segments.each do |ns|
              r1 << [ *one_created_path, ns ]
            end
          end

          r1
        end

        paths_result.concat(r) if r
      end

      Success(res)
    end

    def make_response_object(routes)
      resonse_object = routes.map do |route|
        first_segment = route.first
        last_segment = route.last

        ResponseObject.new(
          first_segment.origin_iata,
          last_segment.destination_iata,
          first_segment.std,
          first_segment.sta,
          route
        )
      end

      Success(resonse_object)
    end
  end
end
