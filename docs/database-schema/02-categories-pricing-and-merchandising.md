# Категории, pricing и merchandising

## Область
Этот файл покрывает дерево категорий, индексы категорий, singleton pricing settings, supplier tariffs и weight-related таблицы.

## Таблицы категорий

### Таблица: `parser_category`
Назначение: дерево категорий backend для catalog/showcase.

### Таблица: `parser_category_keyword`
Назначение: keywords категорий по scope `local`, `title`, `status`.

### Таблица: `parser_category_manual_product`
Назначение: ручные category-product связи.

### Таблица: `parser_product_category_match`
Назначение: вычисленные category matches для catalog products.

### Таблица: `parser_category_count_snapshot`
Назначение: сохраненные счетчики категорий.

### Таблица: `parser_category_index_state`
Назначение: singleton-like маркеры свежести/rebuild category index.

Подробные поля этих таблиц остаются без изменений относительно baseline и читаются backend category services.

## Таблицы pricing

### Таблица: `parser_pricing_settings`
Назначение: singleton-store глобальных параметров pricing formula.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `markup_multiplier` | `FLOAT` | no | `1.0` | базовый markup |
| `weight_tolerance` | `FLOAT` | no | `1.0` | tolerance pricing |
| `promo_factor` | `FLOAT` | no | `1.0` | default promo factor |
| `customs_threshold_eur` | `FLOAT` | no | `200.0` | customs threshold |
| `customs_threshold_currency` | `VARCHAR(3)` | no | `EUR` | валюта threshold |
| `customs_duty_rate` | `FLOAT` | no | `0.15` | ставка duty |
| `usd_to_rub` | `FLOAT` | no | `95.0` | fallback FX |
| `eur_to_rub` | `FLOAT` | no | `105.0` | fallback FX |
| `bybit_usdt_to_rub` | `FLOAT` | no | `95.0` | FX от Bybit |
| `bybit_extra_rub` | `FLOAT` | no | `1.0` | дополнительный spread |
| `final_rounding_mode` | `VARCHAR(32)` | no | `unit` | режим финального округления |
| `bybit_bucket_rates` | `JSON` | no | `[]` | последние snapshots bucket |
| `bybit_last_updated_at` | `TIMESTAMPTZ` | yes | `null` | timestamp refresh rate |
| `bybit_last_error` | `VARCHAR(1024)` | yes | `null` | последняя ошибка provider |
| `eur_to_usd_rate` | `FLOAT` | no | `1.18` | FX |
| `gbp_to_usd_rate` | `FLOAT` | no | `1.4` | FX |
| `jpy_to_usd_rate` | `FLOAT` | yes | `null` | добавлено в `0021`, relaxed в `0022` |
| `payment_fee_rate` | `FLOAT` | no | `0.02` | fee rate |
| `customs_processing_rate` | `FLOAT` | no | `0.08` | customs processing |
| `customs_fixed_rub` | `FLOAT` | no | `540.0` | фиксированный customs fee |
| `shipping_alt_threshold_eur` | `FLOAT` | no | `300.0` | threshold alt shipping |
| `tax_rate` | `FLOAT` | no | `0.06` | tax rate |
| `dedup_only_available_products` | `BOOLEAN` | no | `false` | поведение фильтра dedup |
| `show_product_description` | `BOOLEAN` | no | `true` | флаг description для public/admin |
| `svc_rules` | `JSON` | no | `[]` | service pricing rules |
| `insurance_rules` | `JSON` | no | `[]` на уровне DB | ORM теперь задает более богатые app-defaults |
| `service_fee_rules` | `JSON` | no | `[]` на уровне DB | ORM теперь задает более богатые app-defaults |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- Index: `idx_parser_pricing_settings_updated_at`

Важный current-state факт:
- колонка `shipping_rules` существовала исторически, но удалена миграцией `0037_drop_legacy_shipping_rules`
- актуальный runtime не использует `shipping_rules`; SSR рассчитывается только по `parser_supplier_shipping_rate`

### Таблица: `parser_supplier`
Назначение: граф supplier-ов для SSR и source pricing.

Ключевые поля:
- `id`
- `key`
- `name`
- `category`
- `parent_supplier_id`
- `alt_position`
- `rate_currency`
- timestamps и soft-delete

Особенности current runtime:
- `key` больше не вводится через admin UI
- backend генерирует его по схеме `supplier-{id}`
- `parent_supplier_id` используется для alt supplier относительно base supplier

### Таблица: `parser_supplier_shipping_rate`
Назначение: весовые диапазоны supplier shipping.

Ключевые поля:
- `id`
- `supplier_id`
- `min_kg`
- `max_kg`
- `rate_rub`

Runtime-смысл:
- это единственный source of truth для SSR
- при отсутствии подходящей строки pricing computation помечает product как `manual_required` с причиной `missing_tariff`

## Таблицы веса

### Таблица: `parser_weight_rule`
Назначение: weight buckets, используемые для inferring missing product weight.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `weight_grams` | `INTEGER` | no | — | целевой вес |
| `sort_order` | `INTEGER` | no | `0` | ordering |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `deleted_at` | `TIMESTAMPTZ` | yes | `null` | маркер soft delete |

### Таблица: `parser_weight_keyword`
Назначение: keywords, прикрепленные к weight rule.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `rule_id` | `INTEGER` | no | — | FK на `parser_weight_rule.id`, `ON DELETE CASCADE` |
| `keyword` | `VARCHAR(255)` | no | — | token match |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- FK: `rule_id -> parser_weight_rule.id (CASCADE)`
- Unique: `uq_parser_weight_rule_keyword (rule_id, keyword)`
- Index: `idx_parser_weight_keyword_rule_id`
- Index: `idx_parser_weight_keyword_keyword`
