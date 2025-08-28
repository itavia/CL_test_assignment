# Cargloine Test Assignment

Тестовое задание для кандидата на позицию Backend Ruby on Rails разработчика в проект Cargoline.

## Описание проекта

Rails 8.0.2 API-only приложение для поиска возможных маршрутов перелетов на основе данных о сегментах рейсов и разрешенных маршрутах авиакомпаний.

## Предварительные требования

- **Ruby**: 3.4.x (см. `.ruby-version`)
- **PostgreSQL**: Обязательная СУБД для проекта

## Как оформить ответ

1. **Сделать fork проекта** - создать копию репозитория в своем GitHub аккаунте
2. **Развернуть проект локально и реализовать решение задания** (см. ниже)
3. **Оформить Pull Request** к этому репозиторию с готовым решением

## Настройка проекта

1. **Установка зависимостей:**
   ```bash
   bundle install
   ```

2. **Настройка базы данных и загрузка данных:**
   ```bash
   # Создание БД, выполнение миграций и загрузка тестовых данных файлов
   bundle exec rake db:setup
   ```

### Тестовые данные

После выполнения команды выше, у вас будет созданы соответсвующие таблицы с тестовыми данными:

- **Авиакомпания (carrier):** S7
- **Период рейсов:** 1-7 января 2024 года  
- **Аэропорт отправления (origin iata):** UUS (Южно-Сахалинск)
   

## Модели данных

### Segment (Сегменты рейсов)
Представляет отдельные сегменты перелетов:

```ruby
# == Schema Information
#
# Table name: segments
#
#  id               :integer          not null, primary key
#  airline          :string           not null
#  segment_number   :string           not null
#  origin_iata      :string(3)        not null
#  destination_iata :string(3)        not null
#  std              :datetime         # scheduled time of departure (UTC)
#  sta              :datetime         # scheduled time of arrival (UTC)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
```

**Описание полей:**
- `airline`: Код авиакомпании (например, "S7")
- `segment_number`: Номер рейса, например '0321'
- `origin_iata`: 3-буквенный IATA код аэропорта вылета
- `destination_iata`: 3-буквенный IATA код аэропорта прилета
- `std`: Время вылета по расписанию (scheduled time of departure) (UTC)
- `sta`: Время прилета по расписанию (scheduled time of arrival) (UTC)

### PermittedRoute (Разрешенные маршруты)
Определяет разрешенные маршруты для авиакомпаний:

```ruby
# == Schema Information
#
# Table name: permitted_routes
#
#  id                   :bigint           not null, primary key
#  carrier              :string           not null
#  origin_iata          :string           not null
#  destination_iata     :string           not null
#  direct               :boolean          default(true), not null
#  transfer_iata_codes  :text             default([]), not null, is an Array
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
```

**Описание полей:**
- `carrier`: Код авиакомпании
- `origin_iata`: IATA код аэропорта вылета
- `destination_iata`: IATA код аэропорта прилета
- `direct`: Разрешен ли прямой перелет без пересадок
- `transfer_iata_codes`: Массив кодов аэропортов для возможных пересадок

**Пример записи PermittedRoute:**
```ruby
{
  carrier: "S7",
  origin_iata: "UUS",
  destination_iata: "DME",
  transfer_iata_codes: ["OVB", "KHV", "IKT", "VVOOVB"],
  direct: true
}
```

Маршруты с множественными пересадками в `transfer_iata_codes` указываются строкой, составленной из 3х буквенных IATA-кодов. Например, `"VVOOVB"` означает 2 промежуточных аэропорта - `VVO`  и `OVB`. 
Могут быть стыковки с 2 и более промежуточными аэрпопртами.

**Логика маршрутов:**
- Если `direct: true` - возможен прямой маршрут UUS → DME
- `transfer_iata_codes: ["OVB", "KHV", "IKT", "VVOOVB"]` означает возможные стыковочные маршруты:
  - UUS → OVB → DME
  - UUS → KHV → DME  
  - UUS → IKT → DME
  - UUS → VVO → OVB → DME (двойная пересадка)

## Задание: API для поиска маршрутов

### Требования к реализации

Необходимо создать API для поиска возможных маршрутов перелета с учетом:
- Разрешенных маршрутов из таблицы `PermittedRoute`
- Доступных сегментов из таблицы `Segment`
- Ограничений по времени пересадок
- **Желательно** покрытие тестами на RSpec алогритма поиска

API должно возвращать массив всех возможных вариантов маршрутов согласно PermittedRoute и наличию Segment у заданного carrier для этого маршрута, с учётом времени стыковки между сегментами.
Если по маршруту не найдены сегменты, не возвращать такой маршрут. 

Если не найдено ни одного маршрута с сегментами, возвращать пустой массив.

### Константы времени пересадок

```ruby
MIN_CONNECTION_TIME = 480  # минимальное время для пересадки, мин (8 часов)
MAX_CONNECTION_TIME = 2880 # максимальное время ожидания, мин (48 часов)
```

### Входные параметры API

```json
{
  "carrier": "S7",
  "origin_iata": "UUS", 
  "destination_iata": "DME",
  "departure_from": "2024-01-01",
  "departure_to": "2024-01-07"
}
```

### Ожидаемый формат ответа



**Пример для маршрута UUS → VVO → OVB → DME:**

```json
[
    {
      "origin_iata": "UUS",
      "destination_iata": "DME", 
      "departure_time": "2024-01-01T05:45:00.000Z",
      "arrival_time": "2024-01-02T18:05:00.000Z",
      "segments": [
        {
          "carrier": "S7",
          "segment_number": "6224",
          "origin_iata": "UUS",
          "destination_iata": "VVO",
          "std": "2024-01-01T05:45:00.000Z",
          "sta": "2024-01-01T07:40:00.000Z"
        },
        {
          "carrier": "S7", 
          "segment_number": "5202",
          "origin_iata": "VVO",
          "destination_iata": "OVB",
          "std": "2024-01-01T20:25:00.000Z",
          "sta": "2024-01-02T02:30:00.000Z"
        },
        {
          "carrier": "S7",
          "segment_number": "2514", 
          "origin_iata": "OVB",
          "destination_iata": "DME",
          "std": "2024-01-02T13:40:00.000Z",
          "sta": "2024-01-02T18:05:00.000Z"
        }
      ]
    },
    
    // ... другие варианты маршрута
]
```


### Рекомендуемые данные для тестирования:

- **Carrier:** S7
- **Период:** 1-7 января 2024 года (любые интервалы в этом диапазоне)
- **Маршруты:**
  - UUS → DME 
  - UUS → NOZ 

