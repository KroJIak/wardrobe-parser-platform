# Архитектура parser-service: реестр источников и модель конфигурации

## Область охвата
- Покрывает: `config/sources.json`, `SourceRepository`, `SourceRecord`, секции конфигурации на источник и точное поведение мутаций, доступных через `PATCH /api/v1/sync/sources/{source_key}`.
- Не покрывает: записи об источниках в базе backend или UX управления источниками во frontend.
- Зависит от: `service/config/sources.json`, `service/app/repositories/source_repository.py`, `service/app/services/config_validation_service.py` и контрактов adapter/strategy.

## Владение устойчивой конфигурацией
Единственное подтвержденное устойчивое состояние, которым владеет parser-service, — это файловый реестр источников `config/sources.json`.

`SourceRepository` напрямую читает и пишет этот файл:
- путь по умолчанию: `config/sources.json`
- переопределение: `SOURCES_CONFIG_PATH`
- формат: объект верхнего уровня с единственным массивом `sources`
- стиль записи: полная перезапись файла через `json.dumps(..., indent=2)`

В текущем коде нет частичного хранилища для patch-обновлений, блокировок на уровне строк или внешнего хранилища конфигурации.

## Форма записи источника
Репозиторий возвращает dataclass-структуру:

| Поле | Тип | Значение |
|---|---|---|
| `id` | `int` | локальный для сервиса числовой идентификатор источника |
| `key` | `str` | канонический идентификатор источника, обычно похожий на домен |
| `url` | `str` | базовый URL источника |
| `adapter_key` | `str` | ключ поиска в реестре адаптеров |
| `enabled` | `bool` | верхнеуровневый флаг включения в сервисе |
| `sync_enabled` | `bool` | верхнеуровневый флаг включения в пакетные sync-job |
| `config` | `dict` | вложенная конфигурация среды выполнения парсера |

## Текущее наполнение реестра
Наблюдается в `sources.json`:
- всего источников: `27`
- режимы:
  - `25` источников в `auto`
  - `2` источника в `manual`
- семейства последовательностей стратегий:
  - `21` используют `["shopify_json", "shopify_js"]`
  - `1` использует `["shopify_json"]`
  - `1` использует `["shopify_browser_extension"]`
  - `1` использует `["store_backlash_colorme"]`
  - `1` использует `["vinted_jsonld"]`
  - `1` использует `["grailed_algolia_jsonld"]`
  - `1` использует `["intl_protocol_index_cafe24"]`

## Общие секции конфигурации
Сервис не определяет одну глобальную Pydantic-схему для `source.config`. Вместо этого `ConfigValidationService` проверяет обязательные секции во время выполнения.

### Общие ключи верхнего уровня, встречающиеся в текущем config
| Ключ | Значение |
|---|---|
| `adapter_ready` | маркер готовности, хранимый в config |
| `adapter_revision` | метка ревизии adapter config |
| `strategy_sequence` | упорядоченный список стратегий |
| `retry_limits` | число повторов на стратегию |
| `timeouts` | бюджет таймаутов на уровне источника |
| `mode` | `auto` или `manual` |

### Секции семейства Shopify
| Секция | Обязательна, когда |
|---|---|
| `shopify_sitemap` | имя любой стратегии начинается с `shopify_` |
| `shopify_currency` | имя любой стратегии начинается с `shopify_` |
| `shopify_json_quality` | присутствует `shopify_json` |
| `shopify_js_workers` | присутствует `shopify_js` |
| `shopify_js_quality` | присутствует `shopify_js` |
| `shopify_browser_extension_quality` | присутствует `shopify_browser_extension` |
| `browser_extension` | требуется самой `ShopifyBrowserExtensionStrategy` |

### Наблюдаемые не-Shopify секции
| Секция | Используется кем |
|---|---|
| `vinted.search_text` | discovery для `vinted_jsonld` |
| `grailed.search_text` | discovery для `grailed_algolia_jsonld` |
| `store_backlash_colorme_workers` | параллелизм для `store_backlash_colorme` |
| `intl_protocol_index_workers` | параллелизм для `intl_protocol_index_cafe24` |
| `source_domains` | сопоставление доменов в probe-режиме для multi-host алиасов источника |

## Правила валидации среды выполнения
`ConfigValidationService` обеспечивает следующее:
- `strategy_sequence` должен существовать, быть непустым и содержать только стратегии, разрешенные адаптером.
- `retry_limits` должен существовать, быть непустым и содержать неотрицательные целые.
- `timeouts` должен включать:
  - `product_sec`
  - `source_run_sec`
- Shopify currency method должен быть одним из:
  - `priority_list`
  - `locked_param_currency`
  - `locked_no_currency`
- Коды валют нормализуются к поддерживаемым значениям `EUR`, `USD`, `GBP`, `JPY`, при этом legacy `GBR` приводится к `GBP`.
- `locked_country` при наличии должен быть 2-буквенным алфавитным кодом.
- Для включенных стратегий должны существовать соответствующие quality sections.

## Режимы sync
### `auto`
- Режим по умолчанию.
- Поиск видимого каталога делегируется адаптеру, если вызывающая сторона не форсирует candidate URLs.

### `manual`
- Поиск видимого каталога пропускается.
- Запуск зависит от явных candidate URLs.
- Если candidate URLs не переданы, запуск становится no-op success с `visible_coverage = 1.0`.

Текущие manual-источники:
- `vinted.com`
- `grailed.com`

## Варианты валютной конфигурации
Текущий код поддерживает три эффективных паттерна:

| Метод | Поведение |
|---|---|
| `priority_list` | запрашивать с предпочтительными валютами по порядку |
| `locked_param_currency` | форсировать одну валюту через параметры запроса |
| `locked_no_currency` | не передавать параметр валюты, но все равно считать одну валюту целевым locked output |

Наблюдаемые примеры:
- `newrock.com` использует `locked_param_currency` с `locked_currency = EUR` и `locked_country = DE`
- `rickowens.eu` использует `locked_no_currency` с `locked_currency = EUR`

## Секция browser extension
Только одна текущая конфигурация источника включает настройки `browser_extension`. Эта секция содержит:
- `script_path`
- `scenario_id`
- `export_concurrency`
- `export_max_products`
- `max_collection_pages`
- `skip_discovery_for_limited_json_export`
- `js_sample_size`
- `show_ui`
- `includeLocaleSitemaps`
- `export_mode`
- `prefer_bridge_fetch`

`script_path` обязателен во время выполнения для `shopify_browser_extension`.

Текущая runtime-оговорка:
- `includeLocaleSitemaps` присутствует в проверенной конфигурации источника, но проверенная Python browser strategy этот ключ активно не читает и не передает дальше
- поэтому его следует считать частью хранимой конфигурационной поверхности, а не подтвержденным живым поведением runner

## Операции SourceRepository
### `list_all()`
- читает файл
- валидирует формат верхнего уровня
- возвращает все источники как `SourceRecord`

### `get_by_key(source_key)`
- выполняет точное строковое совпадение по `key`
- выбрасывает `KeyError`, если файл отсутствует, формат невалиден или ключ не найден

### `patch_flags(...)`
Поддерживаемые мутации:
- `enabled`
- `sync_enabled`
- `requested_currency_priority`
- `currency_method`
- `locked_currency`

Детали поведения:
- метод переписывает весь JSON-файл целиком
- patch валюты редактирует только вложенный `config.shopify_currency`
- `GBR` нормализуется в `GBP`
- установка `currency_method = priority_list` очищает `locked_currency`, если новый locked currency не передан

## Поверхность patch, доступная через HTTP API
`PATCH /api/v1/sync/sources/{source_key}` принимает:

```json
{
  "enabled": true,
  "sync_enabled": true,
  "requested_currency_priority": ["EUR", "USD"],
  "currency_method": "locked_param_currency",
  "locked_currency": "EUR"
}
```

HTTP-маршрут возвращает только:
- `id`
- `key`
- `url`
- `adapter_key`
- `enabled`
- `sync_enabled`

Вложенная config в ответ patch-запроса не возвращается.

## Поддержка сопоставления доменов для probe
Probe-маршрут выводит источник через сопоставление домена:
- основной домен берется из `source.url`
- необязательные алиасы берутся из `config.source_domains`

Именно поэтому `source_domains` существует для источников вроде `intl-protocol-index.com`, где реальные product pages могут открываться под `protocolindex.cafe24.com`.
