# Модель данных: Settings Transfer

## Область действия
Эта модель покрывает payload полного export/import/reset конфигурации, обрабатываемые `/api/v1/settings/export`, `/import` и `/reset`.

## Структура export/import payload
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `schema_version` | `int` | да | версия схемы payload |
| `exported_at` | `datetime-string \| null` | нет | timestamp export |
| `project` | `string \| null` | нет | label проекта |
| `pricing_settings` | `settings-transfer-pricing-settings` | да | subset pricing |
| `admin_ui_settings` | `settings-transfer-admin-ui-settings` | да | subset admin UI |
| `suppliers` | `array<settings-transfer-supplier-entry>` | да | graph suppliers |
| `sources` | `array<settings-transfer-source-entry>` | да | настройки источников |
| `weight_rules` | `array<settings-transfer-weight-rule-entry>` | да | rules веса |
| `categories` | `array<settings-transfer-category-entry>` | да | rows категорий |
| `category_keywords` | `array<settings-transfer-category-keyword-entry>` | да | rows keywords |
| `brand_mappings` | `array<settings-transfer-brand-mapping-entry>` | да | rows brand mapping |

## Важные вложенные структуры
### Подмножество pricing
- зеркалирует pricing settings без transient diagnostics/runtime Bybit

### Подмножество admin UI
- `designers_min_products`
- `designers_exclude_store_vendors`
- `auto_sync_period_minutes`
- `showcase_hero_image_asset_id`
- `showcase_carousel_image_asset_ids`

### Элемент источника
- `name`
- `url`
- `enabled`
- `sync_enabled`
- `hide_auto_added_products`
- `show_description`
- `show_images`
- `currency_priority`
- `currency_method`
- `locked_currency`
- `supplier_key`
- `promo_factor`
- `promo_only_no_discount`
- `buyout_surcharge_value`
- `buyout_surcharge_currency`

### Ответ после import/reset
| Поле | Тип |
|---|---|
| `ok` | `bool` |
| `message` | `string` |
| `schema_version` | `int` |
| `imported_at` | `datetime-string` |
| `imported_counts` | `object<string, int>` |

## Представления по доменам
### `frontend`
- `SettingsTransferPayload`
- вложенные типы `SettingsTransfer*`

### `backend`
- `SettingsTransferPayload`
- `SettingsTransferResponse`

### `database`
- payload охватывает несколько backend-owned tables:
  - pricing
  - admin UI settings
  - suppliers
  - source profiles
  - weight rules
  - categories
  - brand mappings

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `database` |
|---|---|---|---|
| nested source settings | те же имена | те же имена | разделено между `parser_source` и service-backed source config во время import/export |
| parent link supplier | `parent_supplier_key` | то же имя | резолвится в `parent_supplier_id` |
| ids showcase media | вложены в `admin_ui_settings` | те же имена | хранятся в `admin_ui_settings` |

## Текущие ограничения
- Export/import orchestrates backend, даже для настроек, которые также затрагивают source config parser-service.
- Версия схемы payload сейчас числовая и по умолчанию равна `1`.
- Transient runtime-поля, такие как текущие jobs или event cursors, не входят в payload transfer.
- `POST /settings/reset` в текущем API работает только целиком; selector-payload для partial reset отсутствует.
- Reset очищает DB settings state, которым владеет backend, но не возвращает `config/sources.json` parser-service к source defaults.
- Import источников может patchить flags, которые backing service, только когда backend может сопоставить live service source по нормализованному host.
- Импортированное `admin_ui_settings.auto_sync_period_minutes` нормализуется к минимуму `60`.
