# Архитектура Backend: Каталог Товаров и Публичный Showcase

## Область
- Покрывает: публичные responses products, ориентированные на catalog/category, admin-поверхности products, CRUD manual catalog, product media, API showcase.
- Не покрывает: правила source registry, internals dedup, детали pricing formula.
- Зависит от: `03-data-layer-and-schema-ownership.md`, `04-sync-and-source-orchestration.md`, `07-pricing-weight-and-settings.md`.

## Обзор
`app/api/v1/products.py` - самый большой file в backend и основная mixed boundary между:

- public reads showcase/catalog;
- admin reads catalog;
- product override mutations;
- manual product CRUD;
- endpoints brand-mapping;
- compatibility proxying в parser-service.

Он также содержит helpers enrichment для:

- projection pricing;
- visibility source;
- manual и indexed categories;
- brand mapping;
- ordering images и manual image URLs.

## Публичная поверхность products
Публичная поверхность, явно включенная в filtered OpenAPI:

- `GET /api/v1/catalog/products`
- `GET /api/v1/products/{product_id}`
- `GET /api/v1/products/images/{image_id}`

### `GET /catalog/products`
Это основной публичный listing catalog для сайта.

Возможности:

- cursor pagination
- search
- filter source
- filter category slug
- filter status (`available`, `out_of_stock`, `hidden`)

Текущая реализация:

1. читает pricing settings и matching weight rules;
2. строит category tree и обеспечивает freshness category index;
3. загружает active products из DB backend, а не из service;
4. применяет source/profile overrides и brand mapping;
5. применяет internal categories и pricing enrichment;
6. проецирует response payload с `items`, `next_cursor`, `has_more`, `limit`.

Следовательно, public catalog - это backend-owned read projection, даже если изначально products были обнаружены parser-service.

### `GET /products/{product_id}`
Public detail product использует только локальное состояние backend.

Поведение:

- загружает active product из repository backend;
- скрывает products со статусом `unavailable` как `404`;
- реконструирует detail payload с image URLs, variants, categories, description и pricing;
- применяет brand mapping и source/profile overrides;
- не опирается на detail fetch parser-service для итогового response.

### `GET /products/images/{image_id}`
Возвращает локально сохраненное manual/internal image из `ImageAsset`.

Используется для:

- uploads images manual product
- internal showcase-style media product, хостящихся backend

## Публичная поверхность showcase
`app/api/v1/showcase.py` публикует media API showcase.

Public reads:

- `GET /api/v1/showcase/state`
- `GET /api/v1/showcase/hero/image`
- `GET /api/v1/showcase/carousel`
- `GET /api/v1/showcase/carousel/{image_id}/image`

Они читают состояние hero и carousel из `AdminUiSettings`, а image files - из `ImageAsset`.

### Эндпоинты мутаций в `showcase.py`
- `POST /showcase/hero/upload`
- `DELETE /showcase/hero`
- `PATCH /showcase/hero`
- `POST /showcase/carousel/upload`
- `PATCH /showcase/carousel/order`
- `DELETE /showcase/carousel/{image_id}`

Важный текущий факт: у этих mutation routes нет auth dependency в inspected code. Admin UI может использовать их как admin actions, но сам backend здесь их не защищает.

## Админское чтение products
Основные admin read endpoints:

| Endpoint | Назначение |
|---|---|
| `GET /api/v1/admin/products/table` | table-oriented admin listing |
| `GET /api/v1/admin/products/table/facets` | значения facets для filters admin table |
| `GET /api/v1/admin/products` | cursor-paginated admin listing |
| `GET /api/v1/products/pricing-example` | random example product для объяснения pricing |

Использование permissions:

- table и admin listings требуют `control.products.read`
- pricing example требует `control.pricing.read`

Эти endpoints повторно используют большую часть того же pipeline enrichment, что и public reads, но поддерживают более широкий набор statuses и admin-only fields.

## Мутации и overrides product
`PATCH /api/v1/products/{product_id}` - это основная admin surface мутации одного product, защищенная `showcase.edit`.

Поддерживаемые операции включают:

- изменение status в пределах public-visible statuses
- set/reset override title
- set/reset override description
- set/reset override visibility description
- patch image / manual ordering changes

Route парсит loose JSON payload, валидирует поддерживаемые fields, загружает product, напрямую мутирует ORM state и возвращает lightweight acknowledgement-style payload product.

Текущий caveat response:
- он не эквивалентен fresh fully enriched read catalog/detail
- в ветке response для patch несколько fields read-model опустошаются или понижаются, включая category projection, favorite state и final pricing
- `pricing_components.reason` может стать `status-only-patch` в этом path response

Это не маленький endpoint passthrough `DTO -> service`, но и не полноценный recomputed contract product-detail.

## Загрузка изображений product
Admin media helpers в `products.py`:

- `POST /products/upload-image`
- `POST /products/upload-image-by-url`

Оба требуют `showcase.edit`.

Детали реализации:

- images валидируются через Pillow;
- files сохраняются в uploads backend;
- запись DB создается в `ImageAsset`;
- upload по remote URL использует `urllib` fetch и сохраняет локальную copy.

## Потоки manual catalog
Manual products - это items, принадлежащие backend, под synthetic manual source.

Endpoints:

- `POST /products/manual`
- `PATCH /products/manual/{product_id}`
- `DELETE /products/manual/{product_id}`
- `POST /products/preview-by-url`
- `POST /products/probe-by-url`

### Поведение create/update для manual
Backend:

- требует title и минимум один variant;
- вычисляет price из минимальной цены variant;
- нормализует status из явного payload или availability;
- хранит manual images как локальные URL `/api/v1/products/images/{id}`;
- может опционально привязать manual item к real product URL source через запись строк `ParserProductOriginVariant`;
- делает `commit` прямо в router logic.

### Поведение delete для manual
Delete - это soft-delete строки product плюс очистка связанных строк:

- origin variants
- product category matches
- manual category links
- favorites
- dedup decisions, в которых участвует product

### Предпросмотр и probe
- `preview-by-url` ищет уже сохраненный matching local product.
- `probe-by-url` вызывает parser-service, чтобы исследовать remote product URL, и возвращает preview payload, еще не сохраненный в persistence.

## Эндпоинты сопоставления брендов
Mapping brand/designer находится в `products.py`, а не в отдельном router designer:

- `GET /admin/brand-mapping` - `control.designers.read`
- `PUT /admin/brand-mapping` - `control.designers.edit`

Эти endpoints участвуют в enrichment product, заменяя normalized vendor keys на mapped display values.

## Поверхность products со starred category
Два endpoints curation showcase на уровне product защищены `showcase.read/edit`:

- `GET /products/starred-categories/options`
- `GET /products/{product_id}/starred-categories`
- `PUT /products/{product_id}/starred-categories`

Они используют favorite categories из category tree и сохраняют manual product-category links, после чего повторно синхронизируют state category index.

## Резервное и совместимое поведение
`GET /api/v1/products` - это специальный compatibility endpoint:

- сначала выполняет proxy в parser-service;
- если upstream возвращает error, выполняет fallback к локальному listing DB;
- если upstream успешен, backend все равно обогащает upstream payload локальными pricing/categories/brand mapping перед возвратом.

Этот endpoint отличается от public site catalog endpoint `/catalog/products`.

## Текущие структурные наблюдения
- Обязанности public/admin/showcase/manual/proxy сосредоточены в одном router file.
- Public OpenAPI считает public только подмножество этого router, но сама организация code эти concerns не разделяет.
- Enrichment product повторяется в нескольких ветках endpoints с немного разными правилами visibility и projection.
- Flows manual product и flows image showcase зависят от одного и того же слоя storage `ImageAsset`, но разделены между `products.py` и `showcase.py`.
