# Протокол: `backend` ↔ `database`

## Обзор

Этот протокол определяет, как модуль `backend` использует PostgreSQL как авторитетный слой хранения данных платформы.

| Аспект | Текущая реализация |
|---|---|
| DB engine | PostgreSQL |
| Слой доступа | SQLAlchemy ORM sessions плюс прямые SQLAlchemy queries |
| Источник session | `get_db()` / `SessionLocal` из backend |
| Authority миграций | только backend |
| Таблица версии Alembic | `alembic_version_backend` |
| Поведение compose init | `backend-db-init` выполняет `alembic upgrade head`; `service-db-init` является no-op |

Backend является единственным inspected-модулем с активным database-контрактом. Он владеет эволюцией схемы, записью строк и orchestration чтения/записи для административных, публичных и sync runtime-данных.

## Владение хранением

### Семейства моделей, которыми владеет backend

| Семейство таблиц | Модели, экспортируемые backend |
|---|---|
| Admin auth | `AdminRole`, `AdminUser` |
| Настройки admin UI и showcase | `AdminUiSettings`, `ImageAsset` |
| Профили parser source | `ParserSource` |
| Parser catalog | `ParserProduct`, `ParserProductOriginVariant`, `ParserFavoriteProduct` |
| Dedup и нормализация vendor | `ParserDedupDecision`, `ParserBrandMapping` |
| Категории и category index | `ParserCategory`, `ParserCategoryKeyword`, `ParserCategoryManualProduct`, `ParserProductCategoryMatch`, `ParserCategoryCountSnapshot`, `ParserCategoryIndexState` |
| Pricing | `ParserPricingSettings`, `ParserSupplier`, `ParserSupplierShippingRate` |
| Weight rules | `ParserWeightRule`, `ParserWeightKeyword` |
| Sync runtime | `SyncJobRuntime`, `SyncAppliedBatch` |
| Legacy exports, которые все еще присутствуют | `Product`, `ProductImage`, `Site` |

Legacy exports остаются в `app/models/__init__.py`, но inspected активные backend-flows сосредоточены на семействах `Parser*`, admin, showcase и sync-runtime.

## Паттерны доступа по возможностям backend

| Возможность backend | Основные семейства таблиц | Паттерн доступа |
|---|---|---|
| Auth и RBAC | `AdminRole`, `AdminUser` | lookup для login, CRUD roles/users, projection permissions |
| Aggregate view источников | `ParserSource`, `ParserProduct`, `ParserProductOriginVariant`, `ParserSupplier` | объединение DB source profile данных backend с registry источников parser-service |
| Публичный каталог | `ParserProduct`, `ParserSource`, `ParserCategory*`, `ParserBrandMapping` | filtered listing продуктов, detail продукта, деревья категорий |
| Модерация каталога admin | `ParserProduct`, `ParserProductOriginVariant`, `ImageAsset`, `ParserFavoriteProduct`, `ParserCategoryManualProduct` | overrides, CRUD ручных продуктов, linkage media, назначение starred categories |
| Модерация dedup | `ParserDedupDecision`, `ParserProduct`, `ParserProductOriginVariant` | генерация candidates и moderator decisions |
| Pricing | `ParserPricingSettings`, `ParserSupplier`, `ParserSupplierShippingRate`, `ParserProduct` | CRUD настроек и projection цены |
| Weight rules | `ParserWeightRule`, `ParserWeightKeyword`, `ParserProduct` | CRUD правил плюс views missing-weight и recalculation |
| Showcase | `AdminUiSettings`, `ImageAsset` | состояние hero и carousel плюс lookup binary assets |
| Sync runtime | `SyncJobRuntime`, `SyncAppliedBatch`, `ParserProduct*`, `ParserSource` | хранение aggregate jobs и применение parser batches |

## Матрица ownership записи

| Семейство таблиц | Владелец записи | Триггерящие flows |
|---|---|---|
| Admin auth | backend | bootstrap login, bootstrap superadmin, admin-экраны roles/users |
| Профили parser source | backend | редактирование source profiles, обновление telemetry после sync |
| Parser catalog | backend | ingest sync, CRUD ручных продуктов, модерация продуктов |
| Таблицы категорий | backend | редактирование дерева категорий, ручные связи category-product, rebuild indexes |
| Decisions dedup | backend | действия модерации dedup и undo |
| Brand mapping | backend | admin UI mapping designers |
| Таблицы pricing | backend | admin UI pricing и suppliers |
| Таблицы weight rules | backend | admin UI веса и seed defaults |
| Настройки showcase/admin UI | backend | admin settings и действия с showcase media |
| Image assets | backend | upload изображений продукта, upload изображений showcase |
| Таблицы sync runtime | backend | aggregate polling sync и применение batches |

Ни один inspected runtime path не записывает эти таблицы напрямую из parser-service.

## Поведение транзакций

### Ожидаемое слоение

Правила проекта для этого репозитория задают `Router -> Service -> Repository -> Model -> DB`, при этом транзакциями должен владеть service layer.

### Текущая реальность backend

Большинство persistence-flows следует через backend services и thin repositories, но inspected code также содержит прямые мутации базы на уровне router в нескольких местах, включая:

- upload helpers в `showcase.py`, вызывающие `db.add()`, `db.commit()` и `db.refresh()`;
- paths назначения product-category, которые удаляют/создают ORM rows и делают commit в router;
- части routers product и sync orchestration, выполняющие прямые ORM queries и commits.

Это является частью текущего реализованного контракта и влияет на то, где фактически находятся границы транзакций сегодня.

## Контракт repository и query

### Роль repository

- repositories в `app/repositories` в основном представляют собой thin wrappers над одним семейством моделей;
- `BaseRepository` предоставляет примитивы `create`, `get_by_id`, `query` и `flush`;
- бизнес-orchestration в основном остается в service-модулях, хотя часть router-кода также выполняет прямую ORM-работу.

### Стиль query

Наблюдаемые стили доступа к базе включают:

- ORM `query(...).filter(...).all()/first()/count()`;
- SQLAlchemy joins между `ParserProduct`, `ParserProductOriginVariant`, `ParserSource` и category tables;
- aggregate counts и rebuild snapshots для browsing по категориям;
- upserts runtime-status для sync jobs и applied batches.

## Контур владения миграциями

| Concern | Текущее правило |
|---|---|
| Source of truth для схемы | `backend/alembic` |
| Путь обновления runtime | `alembic upgrade head` из образа backend |
| Миграции со стороны service | не активны |
| Общий DB URL в compose | да, но ownership схемы это не передает |

Текущая inspected lineage:

- backend содержит 36 Alembic revisions;
- backend создает и обновляет `alembic_version_backend`;
- parser-service получает `DATABASE_URL` в compose, но не владеет активными миграциями и не имеет активного DB runtime path.

## Контракт ingest каталога

Самый важный write-path backend → database это применение parser batch.

```text
parser-service emits product_batch event
  -> backend poller consumes event
  -> backend normalizes incoming parsed products
  -> backend upserts products, origin variants, source telemetry, and sync runtime
  -> backend rebuilds or updates derived category/index state
```

Таким образом, долговременное sync-state находится в ownership backend, хотя выполнение parser происходит в другом месте.

## Контракт публичного чтения

Публичные routes опираются на queries backend к той же схеме:

- корни категорий и деревья ветвей корня берутся из таблиц `ParserCategory*` и index snapshots;
- публичные reads catalog/product берутся из `ParserProduct` плюс enrichment по source/category/pricing;
- reads showcase берутся из `AdminUiSettings` и `ImageAsset`;
- доставка внутренних изображений продукта использует rows `ImageAsset` со stored files.

## Побочные эффекты storage

Database-протокол backend связан с локальным файловым storage для uploaded media:

| Тип asset | Путь в filesystem | Связь в DB |
|---|---|---|
| Uploads showcase | `backend/uploads/showcase` внутри path образа контейнера | row `ImageAsset` с режимом `stored_file` |
| Uploads продукта | `backend/uploads/products` внутри path образа контейнера | row `ImageAsset` с режимом `stored_file` |

База хранит metadata и путь к файлу; сам binary file находится в локальном storage.

## Текущие границы

- Backend является авторитетным writer для всего inspected persistent business state.
- Output parser-service становится долговечным только после применения backend.
- Frontend никогда не обращается к PostgreSQL напрямую.
- Ownership миграций backend эксклюзивен, даже несмотря на то что другие containers в compose разделяют тот же DB URL.
