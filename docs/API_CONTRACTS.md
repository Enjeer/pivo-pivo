# Черновые API-контракты MVP

Контракты описывают границу приложения и серверного каталога. Это не реализованный API и не обещание доступности внешнего провайдера в Минске. Формат JSON/REST, префикс `/v1`; публичные ответы не содержат личных заметок, избранного или состояния пользователя.

## Общие соглашения

- UTF-8, JSON, UTC ISO-8601 timestamp; координаты WGS84.
- Пагинация: ограниченные `limit` и непрозрачный `cursor`; максимальный лимит задаёт сервер.
- Ошибка: `{ "error": { "code": "INVALID_ARGUMENT", "message": "...", "requestId": "..." } }`.
- Сетевые ошибки провайдера представлены как `PROVIDER_UNAVAILABLE`/`PROVIDER_UNSUPPORTED`; не возвращать пустой успешный маршрут при ошибке.
- Для внешних цен/часов/описаний ответ содержит источник и время наблюдения. Отсутствующая информация — `null`/`unknown`.

## Каталог

### `GET /v1/categories`

Ответ: `{ "items": [{ "id": "uuid", "slug": "bar", "name": "Бар", "active": true }] }`.

### `GET /v1/places`

Параметры: `bbox=minLon,minLat,maxLon,maxLat` (необязательный ограниченный bbox), `q`, повторяемые `category`, `limit`, `cursor`.

Ответ:

```json
{
  "items": [{
    "id": "uuid",
    "name": "Название",
    "location": { "latitude": 53.9, "longitude": 27.56 },
    "address": null,
    "categories": [{ "id": "uuid", "slug": "bar", "name": "Бар" }],
    "priceLevel": { "status": "unknown", "currency": "BYN", "source": null, "observedAt": null },
    "dataStatus": "partial"
  }],
  "nextCursor": null
}
```

### `GET /v1/places/{placeId}`

Возвращает расширенную карточку, системные категории, подтверждённые контактные/часовые поля и историю фактов согласно правам. Для каждого изменяемого поля — `source`, `observedAt`, `validUntil?`, `verificationStatus`. Меню, акции и цены не выдаются из внешнего API в собственный каталог без подтверждённых прав.

### `POST /v1/data-reports`

Тело: `{ "placeId": "uuid", "field": "openingHours", "type": "incorrect|closed|missing", "description": "..." }`. Возвращает `{ "reportId": "uuid", "status": "received" }`. Без полей личной заметки, с серверным rate limit и механизмом модерации. Создание комментария не означает подтверждение изменения каталога.

## Маршрут

### `POST /v1/routes/estimate`

Тело:

```json
{
  "origin": { "latitude": 53.9, "longitude": 27.56 },
  "stops": [{ "id": "uuid", "latitude": 53.91, "longitude": 27.57 }],
  "mode": "walking",
  "departureAt": "2026-10-27T18:00:00Z"
}
```

Режимы API: `walking|transit|driving|taxi|personal_car`. Возвращаемые режимы могут отличаться, но неподдерживаемый режим нельзя подменять другим.

Ответ:

```json
{
  "legs": [{
    "fromStopId": "origin",
    "toStopId": "uuid",
    "status": "estimated",
    "distanceMeters": 1200,
    "durationSeconds": 900,
    "cost": { "status": "unknown", "minMinor": null, "maxMinor": null, "currency": "BYN" },
    "source": "google-routes",
    "observedAt": "2026-10-26T20:00:00Z",
    "assumptions": []
  }],
  "totals": {
    "distanceMeters": 1200,
    "durationSeconds": 900,
    "costStatus": "unknown"
  }
}
```

Для нескольких остановок сервер/клиент запрашивает каждое плечо отдельно. Google `TRANSIT` не допускает промежуточные точки. Если одна часть маршрута не рассчитана, отразить неполный ответ с `status: "unavailable"` для этого плеча, не суммировать его стоимость в ноль. Taxi/personal car costing — неизвестно без тарифа/параметров.

В MVP не сохранять ответ маршрута дольше, чем разрешено лицензией. Секретный ключ web-service API не передавать в мобильный клиент.

## Локальный API/контракт домена (не сетевой)

Функции клиентского хранилища:

- `saveFavorite(placeId)`, `removeFavorite(placeId)`, `listFavorites()`;
- `savePlan(plan)`, `reorderStops(planId, stopIds)`, `deleteStop(planId, stopId)`;
- `saveNote(note)`, `deleteNote(noteId)`, `listNotes(filters)`;
- `recalculateBudget(planId)`.

Схема локальных данных соответствует [`DATA_MODEL.md`](./DATA_MODEL.md). Никакого `/notes` endpoint до одобрения синхронизации нет.

## Ошибки и проверка

- `400 INVALID_ARGUMENT`: координаты вне диапазона, неверный bbox, неизвестный режим.
- `404 NOT_FOUND`: внутренний ID не найден.
- `429 RATE_LIMITED`: превышен лимит; вернуть `Retry-After`.
- `502/503 PROVIDER_UNAVAILABLE`: внешний провайдер не ответил/не поддерживает запрос.
- `200` с полем неизвестной цены допустим; `200` с фиктивной оценкой — нет.
- Контрактные тесты обязаны проверять отсутствие личных полей в публичных ответах, порядок остановок, пустые значения и ошибки провайдера.
