# Категории, pricing и merchandising

## Область действия
Этот файл покрывает tables, которые формируют навигацию по категориям, тарификацию suppliers, формулы pricing и оценку веса.

## Таблицы дерева категорий

### Таблица: `parser_category`
Назначение: иерархическое дерево категорий, используемое и в admin-curation, и в навигации публичного каталога.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `name` | `VARCHAR(255)` | no | — | label категории |
| `slug` | `VARCHAR(255)` | no | — | globally unique slug |
| `parent_id` | `INTEGER` | yes | `null` | self-reference на родительскую категорию |
| `is_fallback` | `BOOLEAN` | no | `false` | флаг fallback bucket |
| `is_favorite` | `BOOLEAN` | no | `false` | флаг featured branch |
| `is_enabled` | `BOOLEAN` | no | `true` | флаг видимости |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `deleted_at` | `TIMESTAMPTZ` | yes | `null` | маркер soft delete |

Ограничения и индексы:
- PK: `id`
- Unique: `uq_parser_category_slug`
- FK: `parent_id -> parser_category.id`
- Index: `idx_parser_category_parent_id`
- Index: `idx_parser_category_deleted_at`
- Index: `idx_parser_category_is_fallback`
- Index: `idx_parser_category_is_favorite`
- Index: `idx_parser_category_is_enabled`

Примечание по происхождению:
- `0010_category_slug_ru_style` обновляет seeded slug values, а не структуру

### Таблица: `parser_category_keyword`
Назначение: keyword-rules для автоматического category matching.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `category_id` | `INTEGER` | no | — | FK на `parser_category.id`, `ON DELETE CASCADE` |
| `keyword` | `VARCHAR(255)` | no | — | token match |
| `keyword_scope` | `VARCHAR(16)` | no | `local` | добавлено в `0007` |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- FK: `category_id -> parser_category.id (CASCADE)`
- Unique: `uq_parser_category_keyword_scope (category_id, keyword, keyword_scope)`
- Index: `idx_parser_category_keyword_category`
- Index: `idx_parser_category_keyword_keyword`
- Index: `idx_parser_category_keyword_scope`

### Таблица: `parser_category_manual_product`
Назначение: ручные assignments category-to-product, применяемые admin-tooling.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `category_id` | `INTEGER` | no | — | FK на `parser_category.id`, `ON DELETE CASCADE` |
| `product_id` | `INTEGER` | no | — | FK на `parser_product.id`, `ON DELETE CASCADE` |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- Unique: `uq_parser_category_manual_product`
- FK: `category_id -> parser_category.id (CASCADE)`
- FK: `product_id -> parser_product.id (CASCADE)`
- Index: `idx_parser_category_manual_category`
- Index: `idx_parser_category_manual_product`

### Таблица: `parser_product_category_match`
Назначение: materialized matches категорий для каждого продукта, с source и score.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `product_id` | `INTEGER` | no | — | FK на `parser_product.id`, `ON DELETE CASCADE` |
| `category_id` | `INTEGER` | no | — | FK на `parser_category.id`, `ON DELETE CASCADE` |
| `match_source` | `VARCHAR(16)` | no | `auto` | source code типа `auto` или manual-style |
| `score` | `INTEGER` | no | `0` | score match |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |

Ограничения и индексы:
- PK: `id`
- Unique: `uq_parser_product_category_match (product_id, category_id, match_source)`
- FK: `product_id -> parser_product.id (CASCADE)`
- FK: `category_id -> parser_category.id (CASCADE)`
- Index: `idx_parser_product_category_match_product`
- Index: `idx_parser_product_category_match_category`
- Index: `idx_parser_product_category_match_source`

### Таблица: `parser_category_count_snapshot`
Назначение: предварительно вычисленные direct/subtree counts для public/admin category trees.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `category_id` | `INTEGER` | no | — | PK и FK на `parser_category.id`, `ON DELETE CASCADE` |
| `direct_count` | `INTEGER` | no | `0` | count непосредственных продуктов |
| `subtree_count` | `INTEGER` | no | `0` | count с учетом потомков |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp snapshot |

Ограничения:
- PK: `category_id`
- FK: `category_id -> parser_category.id (CASCADE)`

### Таблица: `parser_category_index_state`
Назначение: технические markers rebuild для materialization matches и counts.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `matches_built_at` | `TIMESTAMPTZ` | yes | `null` | последний rebuild matches |
| `counts_built_at` | `TIMESTAMPTZ` | yes | `null` | последний rebuild counts |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |

Ограничения:
- PK: `id`

## Таблицы suppliers и pricing

### Таблица: `parser_supplier`
Назначение: registry supplier/country, используемый источниками и lookup shipping-rate.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `key` | `VARCHAR(64)` | no | — | уникальный ключ supplier |
| `name` | `VARCHAR(255)` | no | — | отображаемое имя |
| `category` | `VARCHAR(16)` | no | `main` | category supplier |
| `parent_supplier_id` | `INTEGER` | yes | `null` | self-reference для alternate suppliers |
| `alt_position` | `INTEGER` | no | `0` | ordering siblings |
| `rate_currency` | `VARCHAR(3)` | no | `RUB` | валюта tariff |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- Unique: `key`
- FK: `parent_supplier_id -> parser_supplier.id (CASCADE)`
- Index: `idx_parser_supplier_key`
- Index: `idx_parser_supplier_category`

Примечание по происхождению:
- Каноническое содержимое tariff SSR seed'ится и нормализуется в `0014_seed_canonical_ssr`

### Таблица: `parser_supplier_shipping_rate`
Назначение: weight-range shipping tariffs для одного supplier.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `supplier_id` | `INTEGER` | no | — | FK на `parser_supplier.id`, `ON DELETE CASCADE` |
| `min_kg` | `FLOAT` | no | — | нижняя включительная граница веса; введена в `0013` |
| `max_kg` | `FLOAT` | yes | `null` | верхняя граница; введена в `0013` |
| `rate_rub` | `FLOAT` | no | `0.0` | стоимость shipping |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- FK: `supplier_id -> parser_supplier.id (CASCADE)`
- Index: `idx_parser_supplier_shipping_rate_supplier_id`
- Index: `idx_parser_supplier_shipping_rate_min_kg`
- Index: `idx_parser_supplier_shipping_rate_max_kg`

Примечание по происхождению:
- `0002` использовала дискретную модель `step_500g` с unique constraint
- `0013` заменила эту модель на ranges `min_kg` / `max_kg` и удалила старое правило uniqueness

### Таблица: `parser_pricing_settings`
Назначение: singleton-row конфигурации pricing, используемая вычислением цены, currency conversion и behavior-flags каталога.

Ожидание backend:
- Row `id = 1` seed'ится в `0002`
- Таблица трактуется как singleton-store настроек, а не как свободная коллекция

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
| `shipping_rules` | `JSON` | no | `{}` на уровне DB | ORM теперь задает более богатые app-defaults |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- Index: `idx_parser_pricing_settings_updated_at`

Примечание по происхождению:
- `0011` и `0012` добавили admin UI-поля, связанные с designers/showcase
- `0015` добавила media-поля showcase
- `0020` вынесла эти UI-поля в `admin_ui_settings`
- `0021` и `0022` изменили `jpy_to_usd_rate`

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

Ограничения и индексы:
- PK: `id`
- Index: `idx_parser_weight_rule_deleted_at`
- Index: `idx_parser_weight_rule_weight_grams`

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
