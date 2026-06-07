# Модель данных: Source

## Область действия
Эта модель представляет одну строку источника, возвращаемую backend `/api/v1/sources`, объединяя данные registry parser-service с profile-fields и runtime counters, которыми владеет backend.

## Каноническая структура источника
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `key` | `string` | да | source key со стороны service; manual source использует `__manual_admin_source__` |
| `source_id` | `int \| null` | нет | `parser_source.id` backend при наличии mapping |
| `service_source_id` | `int` | нет | file-backed id parser-service; отсутствует во shared-type frontend, но возвращается backend |
| `name` | `string` | да | display name backend или fallback key |
| `base_url` | `string` | да | base URL источника |
| `parser_type` | `string` | да | `parser` или `backend_manual` |
| `enabled` | `bool` | да | флаг включения profile backend |
| `sync_enabled` | `bool` | да | флаг участия в sync на стороне parser-service |
| `hide_auto_added_products` | `bool` | нет | auto-hide ingested products для этого источника |
| `show_description` | `bool` | нет | включать description в public/admin views |
| `show_images` | `bool` | нет | включать images в public/admin views |
| `currency_priority` | `array<string>` | нет | запрошенные currencies |
| `currency_method` | `string` | нет | см. `enums.md` |
| `locked_currency` | `string` | нет | принудительная валюта для locked modes |
| `currency_priority_editable` | `bool` | нет | affordance UI, производный от method |
| `mode` | `string` | нет | mode конфигурации service, обычно `auto` или `manual` |
| `notes` | `string \| null` | нет | сейчас `null` в mapping backend |
| `status_label` | `string \| null` | нет | сейчас `null` в mapping backend |
| `products_count` | `int` | да | общее число связанных продуктов |
| `manual_products_count` | `int` | нет | count только для manual-source |
| `bound_sync_products_count` | `int` | нет | subset manual-source, привязанный к external sync origins |
| `categories_count` | `int` | да | сейчас `0` в mapping backend |
| `last_sync_at` | `datetime \| null` | нет | timestamp sync backend |
| `last_sync_duration_sec` | `int \| null` | нет | длительность последнего sync |
| `last_sync_status` | `string \| null` | нет | результат sync на уровне source или marker password-protected |
| `is_password_protected` | `bool \| null` | нет | производное от статуса последнего sync |
| `is_auto_ingest` | `bool \| null` | нет | производное от mode конфигурации service |
| `is_personal` | `bool` | да | маркер manual catalog source |
| `supplier_id` | `int \| null` | нет | relation supplier backend |
| `supplier_key` | `string \| null` | нет | присутствует во frontend type, выводится в backend read paths при наличии |
| `supplier_name` | `string \| null` | нет | присутствует во frontend type, выводится в backend read paths при наличии |
| `promo_factor` | `float` | да | promo factor уровня source |
| `promo_only_no_discount` | `bool` | да | source promo policy |
| `buyout_surcharge_value` | `float` | да | surcharge выкупа для source |
| `buyout_surcharge_currency` | `string` | да | валюта surcharge |

## Представления по доменам
### `frontend`
- `Source` в `frontend/src/shared/live-data-types.ts`
- Потребляет backend JSON почти без преобразований.

### `backend`
- Строится в `backend/app/api/v1/sources.py` путем объединения:
  - item registry service
  - profile `ParserSource` backend
  - вычисленных counts

### `parser-service`
- Поля `SourceRecord`:
  - `id`, `key`, `url`, `adapter_key`, `enabled`, `sync_enabled`, `config`
- File-backed в `config/sources.json`

### `database`
- `parser_source`
  - `id`, `name`, `url`, `enabled`, `hide_auto_added_products`, `show_description`, `show_images`, `last_sync_at`, `last_sync_duration_sec`, `last_sync_status`, `supplier_id`, `promo_factor`, `promo_only_no_discount`, `buyout_surcharge_value`, `buyout_surcharge_currency`, timestamps, `deleted_at`

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `parser-service` | `database` |
|---|---|---|---|---|
| `key` | `key` | `key` | `SourceRecord.key` | напрямую не хранится |
| `base_url` | `base_url` | выводится из `url` service | `url` | `parser_source.url` |
| `sync_enabled` | `sync_enabled` | service-backed | `sync_enabled` | не хранится в `parser_source` |
| поля `currency_*` | те же имена | выводятся из `config.shopify_currency` service | вложенный `config` | не хранятся в `parser_source` |
| `enabled` | `enabled` | authority profile backend | file flag может существовать отдельно | `parser_source.enabled` |
| `is_personal` | `is_personal` | sentinel manual source | n/a | row manual source в `parser_source` |

## Текущие особые случаи
- Manual catalog source синтезируется backend и хранится как обычная row `parser_source` с URL `manual://admin/products`.
- `categories_count`, `notes` и `status_label` сейчас являются placeholders в mapping backend.
- `sync_enabled` для manual source виден в UI, но функционально не изменяется.
