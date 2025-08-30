# frozen_string_literal: true

module Flights
  class SearchService
    # Вход: params = {carrier:, origin_iata:, destination_iata:, departure_from:, departure_to:}
    def self.call(params)
      # Заглушка. Пока возвращаем пустой массив.
      # В дальнейшем здесь будет поиск маршрутов с учетом сегментов и разрешенных маршрутов
      []
    end
  end
end
