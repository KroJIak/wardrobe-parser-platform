# Устаревшие ingest-таблицы

## Область действия
Этот файл покрывает более старые tables эпохи ingest, которые предшествуют схеме parser catalog. Они все еще существуют в metadata backend и истории Alembic, но inspected current flows backend в основном работают с `parser_*` tables.

## Почему эти tables все еще важны
- Они все еще импортируются в `backend/app/models/__init__.py`.
- Они все еще входят в SQLAlchemy metadata backend.
- Они остаются в истории миграций, начиная с `0001_backend_init`.
- Они представляют отдельную модель хранения относительно текущего parser catalog и должны рассматриваться явно, а не предполагаться взаимозаменяемыми.

## Линия миграций
| Revision | Изменение |
|---|---|
| `0001_backend_init` | создает `sites` и `products` |
| `0003_backend_add_size_info` | добавляет в `products` поля `size` и `additional_info` |
| `0004_backend_product_images` | создает `product_images` |
| `0005_backend_add_size_data` | добавляет в `products` поле `size_data` JSONB |
| `0006_backend_drop_raw_data` | удаляет из `products` поле `raw_data` |

## Таблица: `sites`
Назначение: legacy-registry upstream sites.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `BIGINT` | no | — | primary key |
| `key` | `VARCHAR(64)` | no | — | уникальный site key |
| `name` | `VARCHAR(255)` | no | — | отображаемое имя |
| `base_url` | `VARCHAR(512)` | yes | `null` | base URL source |
| `is_active` | `BOOLEAN` | no | `true` | active flag |
| `last_status` | `VARCHAR(32)` | yes | `null` | последний parser/import status |
| `last_status_at` | `TIMESTAMPTZ` | yes | `null` | timestamp status |
| `last_error` | `TEXT` | yes | `null` | текст последней ошибки |
| `last_error_at` | `TIMESTAMPTZ` | yes | `null` | timestamp ошибки |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `is_deleted` | `BOOLEAN` | no | `false` | флаг soft delete |
| `deleted_at` | `TIMESTAMPTZ` | yes | `null` | timestamp soft delete |

Ограничения и индексы:
- PK: `id`
- Unique: `uq_sites_key`
- Index: `ix_sites_id`
- Index: `ix_sites_key`

## Таблица: `products`
Назначение: legacy-storage продуктов, привязанных напрямую к `sites`.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `BIGINT` | no | — | primary key |
| `site_id` | `BIGINT` | no | — | FK на `sites.id`, `ON DELETE CASCADE` |
| `external_id` | `VARCHAR(128)` | no | — | id продукта в upstream |
| `name` | `VARCHAR(512)` | no | — | title продукта |
| `category` | `VARCHAR(255)` | yes | `null` | legacy-text category |
| `price` | `NUMERIC(12,2)` | yes | `null` | legacy-price |
| `currency` | `VARCHAR(16)` | yes | `null` | валюта цены |
| `size` | `VARCHAR(255)` | yes | `null` | добавлено в `0003` |
| `additional_info` | `TEXT` | yes | `null` | добавлено в `0003` |
| `size_data` | `JSONB` | yes | `null` | добавлено в `0005` |
| `product_url` | `VARCHAR(1024)` | no | — | URL source product |
| `image_url` | `VARCHAR(1024)` | yes | `null` | URL основного изображения |
| `description` | `TEXT` | yes | `null` | description продукта |
| `parser_updated_at` | `TIMESTAMPTZ` | yes | `null` | timestamp обновления upstream |
| `user_updated_at` | `TIMESTAMPTZ` | yes | `null` | timestamp ручного редактирования |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `is_deleted` | `BOOLEAN` | no | `false` | флаг soft delete |
| `deleted_at` | `TIMESTAMPTZ` | yes | `null` | timestamp soft delete |

Ограничения и индексы:
- PK: `id`
- FK: `site_id -> sites.id (CASCADE)`
- Unique: `uq_products_site_external (site_id, external_id)`
- Index: `ix_products_id`
- Index: `ix_products_site_id`
- Index: `ix_products_external_id`

Примечание по происхождению:
- `raw_data JSONB` существовало в `0001` и было удалено в `0006`

## Таблица: `product_images`
Назначение: legacy one-to-many image-table, прикрепленная к `products`.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `BIGINT` | no | — | primary key |
| `product_id` | `BIGINT` | no | — | FK на `products.id`, `ON DELETE CASCADE` |
| `url` | `VARCHAR(1024)` | no | — | URL изображения |
| `sort_order` | `INTEGER` | no | `0` | ordering |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `is_deleted` | `BOOLEAN` | no | `false` | флаг soft delete |
| `deleted_at` | `TIMESTAMPTZ` | yes | `null` | timestamp soft delete |

Ограничения и индексы:
- PK: `id`
- FK: `product_id -> products.id (CASCADE)`
- Unique: `uq_product_images_product_url (product_id, url)`
- Index: `ix_product_images_id`
- Index: `ix_product_images_product_id`

## Текущая позиция в платформе
- Эти tables относятся к более ранней ingest-модели, центрированной вокруг `sites` и `products`.
- Inspected current flows admin catalog, dedup, pricing, category и sync центрированы вокруг `parser_source`, `parser_product` и связанных `parser_*` tables.
- Ни одна migration не удаляет legacy tables, поэтому они остаются частью authoritative schema до будущей явной phase удаления контракта.
