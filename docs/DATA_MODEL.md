# Предварительная модель данных

Дата: 26.10.2026. Внешний каталог и личные записи имеют разные владельцы, политики доступа и сроки хранения.

## Общие соглашения

- UUID/ULID внутреннего ID; внешнее имя не является ключом.
- Время хранить в UTC, в UI показывать локальный часовой пояс Минска.
- Деньги: `amount_minor` целое число в минимальных единицах валюты и `currency` (по умолчанию `BYN`); не использовать `float`.
- Координаты: WGS84 `latitude`, `longitude`; не путать порядок с форматом конкретного API.
- Неизвестное поле остаётся `null`/`unknown`, а не нулём или пустой подтверждённой строкой.
- Внешние поля снабжать источником, временем наблюдения, ссылкой/идентификатором источника, сроком годности при наличии и статусом проверки.

## Каталог (сервер, публичные данные)

### `Place`

`id`, `name`, `normalized_name` (поисковый индекс, не уникальный ключ), `location`, `address`, `status` (`active|temporarily_closed|closed|unverified`), `created_at`, `updated_at`.

### `ExternalPlaceIdentity`

`id`, `place_id`, `provider`, `provider_place_id`, `first_seen_at`, `last_checked_at`. Ограничение уникальности — пара `(provider, provider_place_id)`. Хранить только тот внешний идентификатор, который разрешено хранить.

### `Category` / `PlaceCategory`

Категория имеет `id`, `slug`, локализованные названия/описания и `active`. Связь многие-ко-многим с местом; дополнительные теги отделить от системных категорий.

### `PlaceFact`

Для полей, меняющихся во времени (часы, телефон, сайт, диапазон цен, атрибут, описание): `id`, `place_id`, `field`, `value_json`, `source_type`, `source_ref`, `observed_at`, `valid_until`, `verification_status`, `supersedes_id`.

Данные Google Places, Mapbox Search и иных провайдеров не превращаются автоматически в `PlaceFact`: перед хранением проверяются лицензия и endpoint policy. Сохранять `place_id` отдельно от фактов допустимо по политике Google Places.

### `MenuItem`, `PriceObservation`, `Promotion`

- `MenuItem`: `id`, `place_id`, `name`, `description?`, `active`.
- `PriceObservation`: `id`, `menu_item_id`, `amount_minor?`, `currency`, `price_status`, `source_type`, `source_ref`, `observed_at`, `valid_until?`, `notes?`.
- `Promotion`: `id`, `place_id`, `title`, `terms`, `starts_at?`, `ends_at?`, `source_ref`, `observed_at`, `status`.

Публиковать только данные от заведения/партнёра/проверенного редактора с основанием хранения. Без источника эти данные неизвестны.

### `CrowdObservation` (отложено)

`id`, `place_id`, `kind` (`venue_report|partner_feed|aggregate`), `level` (`low|medium|high|unknown`), `observed_at`, `expires_at`, `confidence`, `sample_count_band?`, `source`, `public_status`. Не хранить/не показывать количество свободных мест, если его не дал официальный источник. Порог агрегации и сроки должны быть установлены отдельной политикой приватности до запуска.

### `DataReport`

Сообщение об ошибке каталога: `id`, `place_id?`, `field?`, `report_type`, `description`, `submitted_at`, `status`, `moderation_note?`. Не содержит личных заметок; ограничение частоты/удаление спама задаются сервером.

## Пользовательские публикации меню (сервер)

### `ContributorAccount`

`id`, `auth_subject`, `created_at`, `status` (`active|limited|suspended|deleted`), `public_display_name?`, `privacy_settings`. Сохранять только идентификатор, необходимый для загрузок, статусов, жалоб и ledger. Точные правила аккаунта/удаления не определены; публикация не даёт доступа к личным заметкам.

### `MenuContribution`

`id`, `place_id`, `contributor_id`, `menu_version_id`, `created_at`, `published_at?`, `status` (`uploaded|processed|published|independently_confirmed|stale|rejected`), `source_label` (`community_upload`), `rights_attestation_version`, `idempotency_key`, `rejection_code?`, `moderation_state`, `supersedes_contribution_id?`.

Статус `independently_confirmed` означает только факт подтверждения независимыми участниками по утверждённому порогу, а не подтверждение от заведения.

### `MenuVersion` / `MenuPage`

- `MenuVersion`: `id`, `place_id`, `created_by`, `created_at`, `published_at?`, `status`, `replaces_version_id?`, `stale_report_count?`, `current_status_updated_at`.
- `MenuPage`: `id`, `menu_version_id`, `page_order`, `image_id`, `uploaded_at`, `published_at?`, `status`, `sha256`, `perceptual_hash`, `width`, `height`, `byte_size`, `mime_type`, `exif_removed_at?`, `quality_status`, `storage_object_key`, `retention_until?`.

Уникальность `(menu_version_id, page_order)`; идентичный SHA-256 на тот же объект не создаёт новую страницу. Перцептивное совпадение хранится как кандидат/сигнал и может быть повторно оценено модератором. В публичном каталоге доступны только опубликованные очищенные изображения.

### `ImageProcessingJob`

`id`, `image_id`, `stage` (`validate|sanitize|quality|duplicate|malware|ocr|extract`), `status`, `attempt`, `idempotency_key`, `provider`, `model_version`, `started_at?`, `completed_at?`, `error_code?`, `cost_units?`. Не сохранять бинарные изображения в job/логе.

### `MenuExtraction` / `ExtractedMenuItem`

- `MenuExtraction`: `id`, `image_id`, `page_order`, `provider`, `model_version`, `raw_text`, `status`, `processed_at`, `overall_confidence?`, `parser_version`.
- `ExtractedMenuItem`: `id`, `extraction_id`, `source_bbox`, `raw_text`, `normalized_name?`, `amount_minor?`, `currency?`, `currency_status`, `ocr_confidence?`, `parser_confidence?`, `validation_status` (`needs_confirmation|published_unverified|independently_confirmed|rejected|stale`), `anomaly_flags`, `supersedes_id?`.

`ocr_confidence` и `parser_confidence` — отдельные величины и не являются доказательством правильной цены. Обязательная ссылка на `image_id`, страницу и координаты; не разрешать detached price record без provenance. Валюта неизвестна, если её нельзя вывести из явного обозначения/проверенного контекста.

### `ContributionReport` / `ModerationAction`

- `ContributionReport`: `id`, `contribution_id`, `reporter_id?`, `type` (`copyright|privacy|wrong_place|stale|quality|other`), `description`, `created_at`, `status`, `decision_due_at?`.
- `ModerationAction`: `id`, `contribution_id`, `actor_id`, `action`, `reason_code`, `created_at`, `previous_status`, `new_status`, `appeal_id?`.

Личные заметки не являются допустимым содержимым жалобы/публичного комментария; ограничить свободный текст и срок его хранения. Каждое скрытие, отклонение, удаление, восстановление и обжалование имеет аудит-событие.

### `ContributionConfirmation`

`id`, `contribution_id` или `extracted_item_id`, `user_id`, `created_at`, `confirmation_type`, `result`, `independence_status`, `risk_flags`. Уникальные ограничения предотвращают многократное подтверждение одним аккаунтом одной версии/позиции. Необходимый порог подтверждений, cooldown и независимость аккаунтов задаются правилами.

## Бонусная экономика

### `RewardRule`

`id`, `version`, `event_type`, `eligibility_json`, `points_delta`, `reputation_delta`, `limits_json`, `effective_from`, `effective_until?`, `active`. Стартовые размеры — конфигурируемые гипотезы. Каждая ledger-запись сохраняет использованную версию правила.

### `ContributionLedgerEntry`

Append-only журнал: `id`, `user_id`, `wallet_type` (`contribution_points|reputation`), `entry_type` (`award|spend|adjustment|reversal|expiry`), `amount_delta`, `reason_code`, `source_event_id`, `idempotency_key`, `rule_id?`, `rule_version?`, `related_entry_id?`, `created_at`, `actor_id?`. Уникальный `idempotency_key`; повторные события возвращают прежний результат. Корректировка создаёт новую строку с причиной, не изменяет историю. Баланс не уходит ниже нуля от concurrent spends: запись/списание атомарны.

Уровень пользователя (`ContributorLevel`) вычисляется по нерасходуемой reputation/XP и версии порогов, а не по очкам в кошельке. Неизменяемая история начисления обеспечивает объяснимость: экран пользователя показывает тип вклада, статус, сумму и правило/причину.

### `RewardItem` / `UserReward`

- `RewardItem`: `id`, `sku`, `kind` (`theme|palette|profile_frame|badge|map_marker|achievement|seasonal|temporary_perk`), `cost_points?`, `availability_start`, `availability_end?`, `duration?`, `requirements_json`, `active`.
- `UserReward`: `id`, `user_id`, `reward_item_id`, `ledger_entry_id?`, `acquired_at`, `starts_at?`, `expires_at?`, `status`.

Фиксированная награда за определённую стоимость; не использовать paid random reward. Сезонные/исследовательские достижения могут иметь критерии, но не должны менять доверие к ценам. `ad_free` не активируется, пока реклама не одобрена отдельным решением.

## Личные данные (локально на устройстве)

### `Favorite`

`place_id`, `created_at`. При необходимости локально хранить минимальный снимок имени/адреса для устаревшей записи — только из собственного каталога с отметкой времени.

### `PersonalNote` / `PersonalTag`

`id`, `place_id?`, `plan_id?`, `body`, `mood_value?`, `created_at`, `updated_at`, `reminder_at?`; метки в отдельных таблицах `PersonalTag(id, label)` и `NoteTag(note_id, tag_id)`.

Это приватные данные: не сериализуются в публичные DTO и не отправляются аналитике или провайдерам. При удалении места заметка сохраняется, а ссылка отображается как архивная.

### `EveningPlan` / `PlanStop`

- `EveningPlan`: `id`, `title`, `planned_at?`, `participants`, `budget_minor?`, `currency`, `created_at`, `updated_at`.
- `PlanStop`: `id`, `plan_id`, `place_id?`, `sequence`, `custom_name?`, `location_snapshot?`, `arrival_at?`, `visit_duration_min?`.
- Уникальность `(plan_id, sequence)`; порядок меняется только по пользовательской команде.
- Снимок координат/имени нужен для корректного отображения сохранённого плана, если каталог поменялся; он должен происходить из собственного каталога.

### `Expense` / `RouteEstimate`

- `Expense`: `id`, `plan_id`, `plan_stop_id?`, `kind` (`food|entry|transport|other`), `label`, `amount_minor?`, `currency`, `estimate_status`, `source`, `observed_at?`, `assumptions?`, `actual_amount_minor?`.
- `RouteEstimate`: `id`, `plan_id`, `from_stop_id`, `to_stop_id`, `mode`, `distance_m?`, `duration_s?`, `cost_min_minor?`, `cost_max_minor?`, `currency`, `provider`, `observed_at`, `departure_at?`, `estimate_status`, `assumptions?`.

Ответы провайдера кэшировать/хранить только если условия этого API разрешают. Пользовательские фактические расходы — отдельные записи и не заменяют оценку.

## Индексы и правила удаления

- Индекс пространственного поиска по координатам каталога (PostGIS, если подтверждён backend) и индекс `normalized_name`.
- Уникальный индекс на внешние идентификаторы, обычные индексы на категорию, статус и `observed_at`.
- Фильтр срока актуальности не удаляет исходную запись; устаревший факт отображается как устаревший/неизвестный.
- Удаление личного плана удаляет его остановки, сметы и заметки, относящиеся только к этому плану; заметка, привязанная также к месту, должна сохраняться по ожидаемому поведению UI.
- Удаление из публичного каталога не должно стирать локальные пользовательские расходы или заметки.
- Индексы для contribution по `place_id/status/published_at`, очереди job по `status/created_at`, exact dedup по SHA-256, approximate dedup по perceptual hash; доступ к storage object key не публичен в карантине.
- По жалобе можно ограничить/скрыть контент без стирания расследовательского audit trail. Удалённый объект удаляется из доступных хранилищ по retention policy; backup retention и legal hold требуют отдельной юридической политики.
- Удаление/блокировка аккаунта не должна создавать повторную награду при восстановлении; ledger хранит требуемый аудит минимально необходимый срок, который должен быть юридически установлен.
- Ledger не удаляется или редактируется для пересчёта баланса: corrections/reversals добавляются как новые события. Удаление купленного за очки предмета не возвращает очки автоматически.
