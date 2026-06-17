# Database Redesign From Admin

> [!info]
> Это **целевая** документация новой БД.
> Она не описывает текущую схему как есть.
> Основание для проектирования: фактические сценарии **admin** как продукта, без обратной совместимости и без сохранения legacy-структур.

## Назначение папки

Эта папка фиксирует новую структуру базы данных для платформы Wardrobe Parser Platform:

- с опорой на реальные сценарии админки;
- с разделением сущностей по строгому смыслу;
- без смешения source-ingest, каталога, ручных override и витринных кэшей в одной таблице;
- с приоритетом нормализованной модели и ясных write-правил.

## Структура

- [[database-redesign-admin/01-admin-scenarios|01-admin-scenarios]]
- [[database-redesign-admin/02-conceptual-chen-model|02-conceptual-chen-model]]
- [[database-redesign-admin/03-logical-schema|03-logical-schema]]
- [[database-redesign-admin/04-state-lifecycle-and-write-rules|04-state-lifecycle-and-write-rules]]
- [[database-redesign-admin/05-sql-constraints-and-indexing|05-sql-constraints-and-indexing]]
- [[database-redesign-admin/06-supporting-contexts|06-supporting-contexts]]
- [[database-redesign-admin/07-legacy-cut-list|07-legacy-cut-list]]
- [[database-redesign-admin/table-attributes/00-INDEX|table-attributes/00-INDEX]]

## Главные проектные решения

> [!success]
> Главный товар каталога и товар источника больше не являются одной сущностью.

> [!success]
> Варианты и изображения больше не живут JSON-массивами внутри товара как source-of-truth.

> [!success]
> Ручные правки админа хранятся отдельно от исходных данных источника.

> [!success]
> Дедуп не создает псевдо-товар вида `dedup://...`. Он управляет связями и канонизацией реальных сущностей.

## Границы новой модели

Новая БД должна покрывать все admin-контуры:

- товары;
- источники;
- дизайнеры;
- фильтры, мультифильтры, категории и кастомные каталоги;
- витринную структуру;
- дедупликацию;
- ценообразование и вес;
- ручные изображения и медиа;
- auth и runtime синхронизации.

## Принцип именования

Для новой схемы принимается стиль:

- таблицы: `snake_case`, **plural**
- PK: `id`
- FK: `<entity>_id`
- справочные таблицы: plural nouns
- связи many-to-many: `<left>_<right>_links`

Примеры:

- `products`
- `product_listings`
- `product_listing_variants`
- `filters`
- `filter_nodes`
- `showcase_settings`

## Что не допускается в новой БД

- одна таблица, одновременно являющаяся и catalog product, и source product;
- статус, смешивающий ingest, availability, moderation и visibility;
- source lineage, от которого зависит UI-логика товара;
- отдельные legacy-острова с пустыми таблицами;
- обязательная бизнес-логика, завязанная на JSON blobs вместо нормальных таблиц.
