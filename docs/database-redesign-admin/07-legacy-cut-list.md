# 07. Legacy Cut List

> [!danger]
> Ниже перечислено то, что не должно переехать в новую БД.

## 1. Старые пустые таблицы

По текущему состоянию БД пусты и при этом не участвуют в живом коде:

- `products`
- `product_images`
- `sites`
- `parser_job`
- `parser_job_source_run`
- `parser_product_delta`
- `parser_product_fingerprint`
- `parser_favorite_product`

Отдельно:

- `products`
- `product_images`
- `sites`

это старый полностью пустой контур товаров, который больше не должен присутствовать даже как параллельная ORM-ветка.

Если при повторной проверке не появится живого runtime-использования, их надо вырезать полностью.

## 2. Legacy-patterns внутри текущего `parser_product`

Не переносить:

- `variants` как JSON source-of-truth;
- `image_urls` как source-of-truth;
- `image_asset_ids` как источник правды;
- `manual_image_asset_ids` как бизнес-модель;
- `hidden_source_image_asset_ids` как бизнес-модель;
- `manual_image_order` как JSON внутри товара;
- `title_override` и единое поле `description_override` внутри товара;
- пара флагов `show_description` + `show_raw_description_html` как бизнес-модель режима описания источника;
- `title_sync_locked`, `description_sync_locked`, `images_sync_locked` внутри товара;
- `auto_hide_force_visible` внутри той же сущности, что и canonical product.

Также не переносить naming-ложь:

- поля с суффиксом `_id`, которые фактически содержат URL;
- image-массивы, которые одновременно играют роль overlay, source snapshot и manual upload registry.
- дубли канонических `title/description`, если они всегда копируют primary listing.

Все это должно быть вынесено в отдельные сущности:

- `product_presentation`
- `product_price_overrides`
- `product_listing_gallery_images`
- `product_listings`
- `product_listing_images`

## 3. Legacy-patterns внутри текущего dedup

Не переносить:

- создание synthetic product с URL вида `dedup://...`;
- неявное хранение результата merge без `created_product_id` и без явного `lifecycle_status = merged` у входных товаров;
- зависимость dedup от materialized variant JSON.

## 4. Legacy-patterns внутри текущего ingest

Не переносить:

- смешение catalog ownership и source ownership;
- поиск продукта то по `external_id`, то по `origin rows`, то по `product.url` на одном уровне;
- глобальную уникальность `product.url`.

Отдельно:

- зависимость текущего matching от того факта, что `origin_variant.source_url == product.url` почти всегда совпадают;
- попытку делать `product` владельцем source identity.

Также вырезать:

- category matching по `status` как keyword-based правилу;
- любые Python full-scan fallback для source/profile lookup по URL/host вместо нормализованных индексируемых ключей.

И не повторять смешение:

- локальной категории товара;
- витринного фильтра;
- верхней витринной категории.

И не смешивать в одном поле:

- source-level возможность выкупить товар;
- витринное состояние `В наличии / Под заказ`;
- lifecycle/visibility status товара.

И не смешивать в одном поле или одной таблице:

- source price;
- source compare-at price;
- derived rub price;
- ручную rub price override;
- ручную rub compare-at price override.

## 5. Legacy naming

В новой БД не использовать:

- `parser_*` для главных бизнес-сущностей;
- `vendor`, если смысл уже `designer`;
- `product_type`, если смысл уже `category`;
- `origin_variant`, если по факту это обычный listing variant.

Новые целевые имена:

- `products`
- `product_listings`
- `product_listing_variants`
- `sources`
- `designers`
- `designer_source_names`
- `filters`
- `custom_catalogs`

## 6. Итоговый cut rule

Любая таблица, которая:

- не является бизнес-сущностью,
- не является явным read-model,
- не является явным runtime-log,
- и не используется admin-сценарием,

не должна существовать в новой БД.
