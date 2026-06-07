# Архитектура parser-service: адаптеры и выбор strategy

## Область охвата
- Покрывает: контракты adapter и strategy, поведение реестров, wiring factory, семейства источников и то, как текущие источники сопоставляются с механизмами выполнения.
- Не покрывает: внутреннее устройство Node browser runner или поведение backend ingestion.
- Зависит от: `service/app/adapters/contracts.py`, `service/app/adapters/*.py`, `service/app/strategies/*.py` и `service/app/services/source_run_service_factory.py`.

## Контракты выполнения
### `SiteAdapter`
Каждый adapter предоставляет:
- `adapter_key`
- `allowed_strategies`
- `discover_visible_catalog(context) -> list[str]`
- `normalize_product(raw_product) -> dict`
- `validate_product(normalized_product) -> tuple[bool, list[str]]`

### `Strategy`
Каждая strategy предоставляет:
- `name`
- `run(context) -> list[dict]`

### Контекстные объекты
- `SourceContext`: идентичность источника, base URL, `adapter_key` и полная source config
- `StrategyContext`: source context, `dry_run`, `run_id`, `candidate_urls`, `candidate_only` и изменяемая diagnostics

## Модель реестров
Сервис использует простые in-memory реестры:
- `AdapterRegistry`: словарь с ключом `adapter_key`
- `StrategyRegistry`: словарь с ключом по имени strategy

Оба выбрасывают `KeyError` при неизвестном lookup. Plugin loader, entry-point discovery и динамический путь импорта отсутствуют.

## Фабрика связывания
`SourceRunServiceFactory.build()` вручную регистрирует каждый adapter и каждую strategy при каждой сборке.

Текущие зарегистрированные adapters включают:
- Shopify-like storefront adapters, такие как `jadedldn__v1`, `essxnyc__v1`, `newrock__v1`
- non-Shopify adapters, такие как:
  - `store_backlash__v1`
  - `vinted__v1`
  - `grailed__v1`
  - `goat__v1`
  - `intlprotocolindex__v1`

Текущие зарегистрированные strategies:
- `shopify_json`
- `shopify_js`
- `shopify_browser_extension`
- `store_backlash_colorme`
- `vinted_jsonld`
- `grailed_algolia_jsonld`
- `goat_browser_extension`
- `intl_protocol_index_cafe24`

## Текущая карта семейств источников
### Базовое семейство Shopify
Большинство источников используют:
- adapter-specific normalization/validation
- сначала `shopify_json`
- затем fallback `shopify_js`

Это доминирующий паттерн в текущем реестре.

### Семейство browser extension
- `shopify_browser_extension` существует для browser-based export
- `goat_browser_extension` оборачивает ту же реализацию, но выдает GOAT-specific strategy name
- в текущем `sources.json` один источник использует `shopify_browser_extension`
- `goat_browser_extension` зарегистрирован, но не встречается в текущих source sequences

### Семейство manual marketplace
- `vinted_jsonld`
- `grailed_algolia_jsonld`

Они запускаются в режиме `manual` и также могут принимать явные probe candidate URLs.

### Специализированное не-Shopify семейство
- `store_backlash_colorme`
- `intl_protocol_index_cafe24`

Они реализуют собственные пути discovery и page parsing.

## Чем владеют adapters
Adapters — это место, где идентичность источника превращается в поведение парсера:
- какие стратегии допустимы
- как обнаруживаются URL видимого каталога
- как raw strategy payload преобразуется в единую форму parser-product
- какие поля обязательны, чтобы продукт считался valid или unavailable

Примеры:
- `GoatV1Adapter` разрешает только `goat_browser_extension`
- `VintedV1Adapter` разрешает только `vinted_jsonld`
- Shopify-like adapters часто разделяют паттерны normalization, но все равно имеют уникальные `adapter_key` и `revision`

## Чем владеют strategies
Strategies реализуют механизмы извлечения, а не идентичность источника:

| Strategy | Базовый механизм |
|---|---|
| `shopify_json` | пагинация Shopify JSON endpoints с валютной политикой и необязательной прямой загрузкой candidate |
| `shopify_js` | конкурентная загрузка `.js` payload для каждого продукта |
| `shopify_browser_extension` | вызов Node/Chromium browser runner и чтение JSON output |
| `vinted_jsonld` | discovery/search по Vinted и парсинг product data из HTML/JSON-LD/runtime scripts |
| `grailed_algolia_jsonld` | discovery через Algolia, затем парсинг listing pages |
| `store_backlash_colorme` | обход Colorme sitemap и парсинг product pages |
| `intl_protocol_index_cafe24` | сочетание sitemap и обхода категорий на Cafe24 storefront |

## Правила выбора strategy
- Порядок стратегий полностью задается `source.config.strategy_sequence`.
- Adapter ограничивает множество допустимых имен через `allowed_strategies`.
- Сервис не выбирает fallback автоматически; он выполняет сконфигурированную последовательность по порядку.
- Покрытие может досрочно остановить последовательность, когда все видимые продукты уже учтены.

## Общие ожидания от validation
Для разных adapters повторяются общие machine-readable reasons:
- `missing_url`
- `missing_handle`
- `missing_title`
- `missing_price`
- `missing_currency`
- `missing_weight`
- `missing_variants`

Некоторые adapters добавляют более узкие правила, например `unsupported_currency`.

## Операционные последствия текущего дизайна
- Добавление или удаление семейства источников требует изменений кода в factory и обычно нового adapter или strategy class.
- Регистрация легко читается, но остается повторяющейся и централизованной.
- Неверный `adapter_key` или имя strategy выявляются только во время выполнения, когда источник действительно используется.
