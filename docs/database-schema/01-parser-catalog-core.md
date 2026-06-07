# Базовое ядро parser catalog

## Область действия
Этот файл покрывает parser-facing catalog tables, которые обеспечивают конфигурацию источников, curated products, модерацию dedup, нормализацию brand, lineage variants, favorites и storage изображений.

## Таблица: `parser_source`
Назначение: один настроенный upstream storefront source.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `name` | `VARCHAR(255)` | no | — | admin-facing label |
| `url` | `VARCHAR(2048)` | no | — | base URL source |
| `enabled` | `BOOLEAN` | no | `true` | флаг включения source |
| `hide_auto_added_products` | `BOOLEAN` | no | `false` | добавлено в `0016` |
| `show_description` | `BOOLEAN` | no | `true` | добавлено в `0026` |
| `show_images` | `BOOLEAN` | no | `true` | добавлено в `0026` |
| `last_sync_at` | `TIMESTAMPTZ` | yes | `null` | добавлено в `0027` |
| `last_sync_duration_sec` | `INTEGER` | yes | `null` | добавлено в `0027` |
| `last_sync_status` | `VARCHAR(32)` | yes | `null` | добавлено в `0027` |
| `supplier_id` | `INTEGER` | no | — | FK на `parser_supplier.id`, `ON DELETE RESTRICT` |
| `promo_factor` | `FLOAT` | no | `1.0` | multiplier уровня source |
| `promo_only_no_discount` | `BOOLEAN` | no | `false` | режим promotion source |
| `buyout_surcharge_value` | `FLOAT` | no | `0.0` | surcharge, специфичный для source |
| `buyout_surcharge_currency` | `VARCHAR(3)` | no | `RUB` | валюта surcharge |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `deleted_at` | `TIMESTAMPTZ` | yes | `null` | маркер soft delete |

Ограничения и индексы:
- PK: `id`
- FK: `supplier_id -> parser_supplier.id (RESTRICT)`
- Нет unique constraint на `url` или `name`

Сценарии доступа:
- Read/write через backend source settings и flows sync orchestration
- Косвенное чтение parser-service через backend `/api/v1/sync/sources`

## Таблица: `parser_product`
Назначение: curated record продукта, сохраняемый backend из batches parser-service и затем обогащаемый admin-tooling.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `source_id` | `INTEGER` | no | — | FK на `parser_source.id` |
| `source_external_id` | `VARCHAR(255)` | yes | `null` | добавлено в `0025` |
| `canonical_url` | `VARCHAR(2048)` | yes | `null` | добавлено в `0025` |
| `handle` | `VARCHAR(1024)` | no | — | upstream handle |
| `title` | `VARCHAR(2048)` | no | — | текущий display title |
| `description` | `TEXT` | yes | `null` | текущее description |
| `vendor` | `VARCHAR(255)` | yes | `null` | upstream vendor/brand text |
| `product_type` | `VARCHAR(255)` | yes | `null` | upstream product type |
| `url` | `VARCHAR(2048)` | no | — | создан как unique в `0002`; migration на удаление все еще отсутствует |
| `price` | `FLOAT` | yes | `null` | representative price верхнего уровня |
| `status` | `productstatus` | no | `available` | enum: `available`, `out_of_stock`, `hidden`, `unavailable` |
| `image_count` | `INTEGER` | no | `0` | derived image count |
| `image_urls` | `JSON` | no | `[]` | URL source images |
| `image_asset_ids` | `JSON` | no | `[]` | JSON field ссылок на изображения с legacy-именем; текущий runtime по-прежнему трактует его обобщенно, а не как ids с FK |
| `title_override` | `TEXT` | yes | `null` | добавлено в `0017` |
| `description_override` | `TEXT` | yes | `null` | добавлено в `0017` |
| `title_sync_locked` | `BOOLEAN` | no | `false` | добавлено в `0017` |
| `description_sync_locked` | `BOOLEAN` | no | `false` | добавлено в `0017` |
| `description_visible_override` | `BOOLEAN` | yes | `null` | добавлено в `0034` |
| `images_sync_locked` | `BOOLEAN` | no | `false` | добавлено в `0017` |
| `hidden_source_image_asset_ids` | `JSON` | no | `[]` | добавлено в `0017`; текущий runtime хранит здесь URL скрытых source images |
| `manual_image_asset_ids` | `JSON` | no | `[]` | добавлено в `0017`; текущий runtime хранит здесь URL manual images, отдаваемых backend |
| `manual_image_order` | `JSON` | no | `[]` | добавлено в `0017`; текущий runtime хранит tokens порядка вроде `m:/api/v1/products/images/{id}` |
| `variants` | `JSON` | no | `[]` | summary variants, хранимый backend |
| `is_auto_added` | `BOOLEAN` | no | `true` | добавлено в `0016` |
| `auto_hide_force_visible` | `BOOLEAN` | no | `false` | добавлено в `0016` |
| `weight_grams` | `FLOAT` | yes | `null` | resolved weight |
| `weight_source` | `VARCHAR(32)` | yes | `null` | provenance rule/probe/manual |
| `weight_match_keyword` | `VARCHAR(255)` | yes | `null` | совпавший keyword |
| `weight_value` | `FLOAT` | yes | `null` | raw upstream value weight |
| `weight_unit` | `VARCHAR(16)` | yes | `null` | raw upstream unit weight |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `deleted_at` | `TIMESTAMPTZ` | yes | `null` | маркер soft delete |

Ограничения и индексы:
- PK: `id`
- FK: `source_id -> parser_source.id`
- Unique constraint из `0002`: `url`
- Index: `idx_parser_product_source_external_id (source_id, source_external_id)`
- Index: `idx_parser_product_source_canonical_url (source_id, canonical_url)`
- Колонка `currency` существовала в `0002` и была удалена в `0030`; currency на уровне variant перенесена в `parser_product_origin_variant`

Сценарии доступа:
- Записывается backend sync-ingestion из batch events parser-service
- Читается admin catalog, public catalog, previews pricing, tooling dedup и rebuild indexes категорий

## Таблица: `parser_product_origin_variant`
Назначение: lineage по каждому variant для aggregated catalog products через один или несколько source variants.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `origin_key` | `VARCHAR(512)` | no | — | уникальный ключ lineage |
| `product_id` | `INTEGER` | no | — | FK на `parser_product.id`, `ON DELETE CASCADE` |
| `source_id` | `INTEGER` | no | — | FK на `parser_source.id`, `ON DELETE RESTRICT` |
| `source_product_url` | `VARCHAR(2048)` | no | — | URL source product |
| `source_variant_id` | `VARCHAR(255)` | yes | `null` | identifier source variant |
| `source_variant_title` | `VARCHAR(1024)` | yes | `null` | title source variant |
| `sku` | `VARCHAR(255)` | yes | `null` | source SKU |
| `price` | `FLOAT` | yes | `null` | цена variant |
| `currency` | `VARCHAR(3)` | yes | `null` | валюта variant |
| `available` | `BOOLEAN` | no | `true` | флаг доступности |
| `payload` | `JSON` | no | `{}` | raw fragment payload variant |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |

Ограничения и индексы:
- PK: `id`
- Unique: `uq_parser_product_origin_variant_origin_key`
- FK: `product_id -> parser_product.id (CASCADE)`
- FK: `source_id -> parser_source.id (RESTRICT)`
- Index: `idx_parser_origin_variant_product_id`
- Index: `idx_parser_origin_variant_source_id`

Примечание по происхождению:
- Введена в `0029`
- Migration backfilled по одной synthetic-row на существующий продукт, используя `origin_key = 'legacy:' || product.id`

## Таблица: `parser_favorite_product`
Назначение: one-to-one favorite marker, прикрепленный к parser product.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `product_id` | `INTEGER` | no | — | unique FK на `parser_product.id`, `ON DELETE CASCADE` |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- Unique: `product_id`
- FK: `product_id -> parser_product.id (CASCADE)`
- Index: `idx_parser_favorite_product_product_id`

## Таблица: `parser_dedup_decision`
Назначение: сохраненное moderator decision для candidate duplicate pair.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `pair_key` | `VARCHAR(64)` | no | — | уникальный стабильный identifier пары |
| `left_product_id` | `INTEGER` | no | — | FK на `parser_product.id` |
| `right_product_id` | `INTEGER` | no | — | FK на `parser_product.id` |
| `action` | `VARCHAR(20)` | no | — | decision code типа merge/reject/combine |
| `merged_into_product_id` | `INTEGER` | yes | `null` | FK на surviving `parser_product.id` |
| `snapshot_payload` | `JSON` | yes | `null` | добавлено в `0033` |
| `restore_payload` | `JSON` | yes | `null` | добавлено в `0033` |
| `decided_at` | `TIMESTAMPTZ` | no | `now()` | timestamp moderator decision |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания строки |

Ограничения и индексы:
- PK: `id`
- Unique: `pair_key`
- FK: `left_product_id -> parser_product.id`
- FK: `right_product_id -> parser_product.id`
- FK: `merged_into_product_id -> parser_product.id`
- Index: `idx_parser_dedup_decision_action`
- Index: `idx_parser_dedup_decision_left`
- Index: `idx_parser_dedup_decision_right`

## Таблица: `parser_brand_mapping`
Назначение: ручная нормализация upstream brand text в canonical display brand names.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `source_brand` | `VARCHAR(255)` | no | — | исходный brand text |
| `source_brand_key` | `VARCHAR(255)` | no | — | нормализованный ключ, unique |
| `target_brand` | `VARCHAR(255)` | no | — | canonical brand |
| `include_in_designers` | `BOOLEAN` | no | `true` | добавлено в `0019` |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |

Ограничения и индексы:
- PK: `id`
- Unique: `source_brand_key`
- Index: `idx_parser_brand_mapping_source_brand`

Примечание по происхождению:
- Создана в `0018`
- Расширена в `0019`

## Таблица: `image_asset`
Назначение: общая media-таблица assets, используемая потоками product и showcase.

### Колонки runtime-слоя
| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `source_url` | `VARCHAR(2048)` | no | — | добавлено и backfilled в `0035` |
| `storage_mode` | `VARCHAR(50)` | no | — | добавлено и backfilled в `0035` |
| `stored_path` | `VARCHAR(2048)` | yes | `null` | добавлено в `0035` |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | исходная column таблицы |
| `deleted_at` | `TIMESTAMPTZ` | yes | `null` | маркер soft delete |

### Сохраненные legacy-колонки, все еще присутствующие в таблице
| Колонка | Тип | NULL после `0036` | Источник |
|---|---|---:|---|
| `kind` | `VARCHAR(32)` | yes | `0002` |
| `storage_rel_path` | `VARCHAR(1024)` | yes | `0002` |
| `mime_type` | `VARCHAR(128)` | yes | `0002` |
| `size_bytes` | `BIGINT` | yes | `0002` |
| `sha256` | `VARCHAR(64)` | yes | `0002` |
| `width` | `INTEGER` | yes | `0002` |
| `height` | `INTEGER` | yes | `0002` |
| `updated_at` | `TIMESTAMPTZ` | no | `0002` |

Ограничения и индексы:
- PK: `id`
- Index retained from `0002`: `idx_image_asset_kind`
- Index retained from `0002`: `idx_image_asset_sha256`
- Нет foreign keys из JSON-массивов image ids в `parser_product` или полей images showcase в `admin_ui_settings`

Примечание по происхождению:
- `0002` создала table, ориентированную на file metadata
- `0035` добавила runtime-columns и backfilled их из legacy storage paths
- `0036` намеренно сняла `NOT NULL` со старых columns вместо их удаления

## Операционные примечания
- `parser_product`, `parser_product_origin_variant` и `image_asset` образуют основной persisted graph каталога, который потребляют tooling продуктов admin и reads публичного каталога.
- Soft deletion применен неравномерно: `parser_product` и `parser_source` используют `deleted_at`; favorites и dedup decisions не используют.
- Source-facing enums статуса parser и статуса продукта являются application-контрактами; только статус curated product представлен PostgreSQL enum type (`productstatus`).
