# Архитектура parser-service: контракты с backend и обогащение веса

## Область охвата
- Покрывает: получение weight-rule из backend, вызовы sync control из backend в service, ожидания к полезной нагрузке вокруг `product_batch` и разделенное владение между backend source data и service source config.
- Не покрывает: backend database repositories или реализацию frontend polling.
- Зависит от: `service/app/services/weight_rules_client.py`, `service/app/services/weight_enrichment_service.py`, `service/app/api/v1/sync.py` и `service/app/services/sync_orchestrator_service.py`.

## Направление интеграции 1: service -> backend
Сервис активно вызывает один backend endpoint:

```text
GET {backend_base_url}/api/v1/public/parser-contract/weight-rules
```

### Поведение клиента
`WeightRulesClient.fetch()`:
- использует таймаут 10 секунд по умолчанию
- вызывает публичный маршрут parser-contract
- при любом сбое возвращает:
  - `revision = "unavailable"`
  - `rules = []`

### Форма разбираемой полезной нагрузки
Каждое принятое правило содержит:
- `weight_grams`
- `keywords[]`

Правила с неположительным весом отбрасываются.

## Поведение weight enrichment
`WeightEnrichmentService.apply_keyword_weight(product, rules)` применяет правила, полученные от backend, после нормализации адаптером.

### Порядок приоритета
1. если источник уже передал положительный `weight_grams`, значение сохраняется и помечается `weight_source = source`
2. иначе строится поисковый набор строк из:
   - title
   - handle
   - product type
   - tags
3. выбирается лучшее совпавшее keyword-правило
4. если совпадение найдено:
   - установить `weight_grams`
   - установить `weight_source = keyword_rule`
5. иначе:
   - установить `weight_source = missing`

При равенстве побеждает:
- более длинное keyword
- затем больший вес, если длины keyword совпадают

## Направление интеграции 2: backend -> service
Контракт, который этот сервис предоставляет backend, — это поверхность `/api/v1/sync/*`.

Backend использует его для:
- чтения реестра источников
- patch-обновления source flags и currency
- создания sync-job
- создания probe-job
- polling статуса
- polling событий
- отмены

## Разделение владения источниками
Текущая реализация использует разделенное владение источниками:

| Область | Текущий владелец |
|---|---|
| parser strategy/runtime config | parser-service `config/sources.json` |
| admin-facing source profile data | база и API backend |
| authoring weight rule | backend |
| source enable/sync toggles, доступные через service API | файловый реестр parser-service |

Из-за этого backend может агрегировать service-side source config со своей более богатой source model.

## Контракт события `product_batch`
Самая важная межсервисная полезная нагрузка среды выполнения — это событие `product_batch` оркестратора.

### Поля полезной нагрузки batch
- `batch_id`
- `source_key`
- `strategy`
- `stage`
- `items[]`

### Правила нормализации item
`SyncOrchestratorService._normalize_product_batch_item(...)` формирует:
- поля source lineage
- canonical URL и handle
- title, description, vendor, product type
- price и weight
- normalized status
- список изображений
- buyer pricing fields, если они присутствуют
- variants с source lineage на уровне variant

Правила пропуска перед попаданием item в `product_batch`:
- у item должен оставаться `source_product_url`
- у item должен оставаться непустой массив `variants[]`

Дополнительные нормализованные поля item, наблюдаемые в текущей среде выполнения:
- `external_id`
- `unavailable_reason`
- `buyer_total_price`
- `buyer_service_fee`

### Варианты lineage
Каждый нормализованный variant несет:
- `source_key`
- `source_product_url`
- `source_variant_id`
- `source_variant_title`

Это сохраняется специально для безопасного downstream combine- или merge-поведения.

## Фильтрация unavailable products
Orchestrator намеренно не пересылает все unavailable products.

Текущее правило:
- в `product_batch` могут попасть только продукты, чьи unavailable reasons в точности равны `{"missing_weight"}`
- любой продукт с `missing_currency` или любой другой unavailable reason исключается из batch

Это бизнес-правило встроено в parser-service во время выполнения, а не отложено на backend.

## Трансляция статуса в batch
`_normalize_product_batch_item(...)` также корректирует status на основе variants:
- если статус item равен `available`, но ни один variant недоступен -> принудительно `out_of_stock`
- если статус item равен `out_of_stock`, но хотя бы один variant доступен -> принудительно `available`

## Трансляция ошибок на HTTP-границе
Текущее отображение ошибок на уровне маршрутов, важное для backend:
- плохая parser config -> HTTP `400`
- неизвестный source/job -> HTTP `404`
- конфликт активного sync -> HTTP `409`

Точность по probe-cancel:
- обычный sync cancel имеет явный путь `404` для неизвестной job
- probe-job cancel в текущей проверенной реализации маршрута не защищает случай отсутствующей job тем же явным `404`-ветвлением

Сервис не реализует более богатый общий cross-service error envelope сверх `detail`.

## Последствия связности
- Backend и parser-service тесно связаны через зеркальные sync-концепции.
- Сервис зависит от backend для актуальных weight rules.
- Backend зависит от семантики service events, особенно `product_batch`, чтобы преобразовать parsed output в persistent catalog state.
