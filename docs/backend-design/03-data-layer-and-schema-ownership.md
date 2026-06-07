# Архитектура Backend: Слой Данных и Владение Схемой

## Область
- Покрывает: настройку SQLAlchemy, группы models, repositories, ownership migrations, boundaries persistence, текущее transaction behavior.
- Не покрывает: бизнес-правила отдельных features или parser-service internals.
- Зависит от: `01-project-setup.md`, `02-auth-and-rbac.md`.

## Владение storage
Backend является владельцем schema для общей PostgreSQL database, используемой платформой.

Подтверждения в текущем runtime:

- SQLAlchemy metadata собирается из `backend/app/models`;
- Alembic расположен в `backend/alembic`;
- таблица версий - `alembic_version_backend`;
- Compose запускает `backend-db-init: alembic upgrade head`;
- Compose запускает `service-db-init` как явный no-op;
- `service` по-прежнему получает тот же `DATABASE_URL`, но активного ownership migrations там не найдено.

Это означает, что backend владеет эволюцией schema даже для таблиц, которые parser-service тоже читает или косвенно затрагивает.

## Инвентарь ORM-моделей
`app/models/__init__.py` экспортирует полный набор metadata.

### Активные группы моделей
| Группа | Models |
|---|---|
| Admin auth | `AdminRole`, `AdminUser` |
| Admin UI / showcase settings | `AdminUiSettings`, `ImageAsset` |
| Parser sources и products | `ParserSource`, `ParserProduct`, `ParserProductOriginVariant`, `ParserFavoriteProduct`, `ParserDedupDecision`, `ParserBrandMapping` |
| Categories и indexing | `ParserCategory`, `ParserCategoryKeyword`, `ParserCategoryManualProduct`, `ParserProductCategoryMatch`, `ParserCategoryCountSnapshot`, `ParserCategoryIndexState` |
| Pricing | `ParserPricingSettings`, `ParserSupplier`, `ParserSupplierShippingRate` |
| Weight | `ParserWeightRule`, `ParserWeightKeyword` |
| Sync runtime | `SyncJobRuntime`, `SyncAppliedBatch` |

### Устаревшие экспорты, которые все еще присутствуют
- `Product`
- `ProductImage`
- `Site`

Эти legacy models все еще входят в metadata и историю migrations, хотя не являются центральными для текущих parser-catalog flows.

## Слой repositories
Repositories находятся в `app/repositories/` и намеренно остаются thin.

`BaseRepository` предоставляет:

- `create(**kwargs)`
- `get_by_id(entity_id)`
- `query()`
- `flush()`

Concrete repositories в основном оборачивают один class model:

- `AdminRoleRepository`, `AdminUserRepository`
- `ParserProductRepository`
- `ParserSourceRepository`
- `ParserCategoryRepository`, `ParserCategoryKeywordRepository`
- `ParserCategoryManualProductRepository`
- `ParserCategoryCountSnapshotRepository`
- `ParserCategoryIndexStateRepository`
- `ParserProductCategoryMatchRepository`
- `ParserFavoriteProductRepository`
- `ParserDedupDecisionRepository`
- `ParserPricingSettingsRepository`
- `ParserSupplierRepository`
- `ParserWeightRuleRepository`, `ParserWeightKeywordRepository`
- `ParserBrandMappingRepository`

Слой repositories не является единственным путем доступа к DB. Многие routers и services по-прежнему напрямую выполняют `db.query(...)`, `db.add(...)` и `db.commit()`.

## Владение persistence по зонам
Текущее фактическое ownership выглядит так:

| Зона | Основной writer в backend | Примечания |
|---|---|---|
| Admin accounts/roles | `AdminAccountsService` | startup bootstrap + CRUD |
| Source profile flags | `sources.py` + sync orchestration helpers | merged with service source registry |
| Parser products | sync apply logic в `jobs.py`, manual product flows в `products.py` | automated и manual writes одновременно |
| Category tree и manual links | `CategoryTreeService`, `CategoryIndexService` | плюс direct writes в starred-category flow product |
| Dedup decisions | `DedupService` | влияет на поведение availability product |
| Pricing settings и suppliers | `PricingSettingsService` | также читает external FX data |
| Правила веса | `WeightRuleService` | public parser contract выводится из тех же таблиц |
| Admin UI / showcase state | `PricingSettingsService`, `showcase.py` | hero/carousel ids хранятся в admin UI settings |
| Sync runtime | `jobs.py` | `SyncJobRuntime`, `SyncAppliedBatch` |

## Инвентарь миграций
Проверенное число revisions: `36` файлов в `backend/alembic/versions`, от `0001_backend_init.py` до `0036_relax_legacy_image_asset_not_null.py`.

Наблюдаемые темы эволюции schema:

- backend init и legacy product tables;
- parser core adoption;
- category keywords и manual links;
- category index snapshots;
- admin auth;
- pricing, suppliers, weight rules;
- showcase/image asset alignment;
- sync runtime и admin UI auto-sync fields;
- dedup decision snapshots.

## Детали runtime Alembic
`backend/alembic/env.py`:

- импортирует `Base.metadata` из backend;
- устанавливает `version_table="alembic_version_backend"` для online и offline runs;
- заранее обеспечивает существование version table и возможность хранения длинных revision ids;
- использует live connection migration flow с `engine_from_config(...)`.

Следовательно, backend-процесс владеет и определением metadata, и conventions bootstrap migrations.

## Реальность границ транзакций
Паттерн проекта предпочитает `Router -> Service -> Repository`, где транзакциями владеет service layer. Текущий код следует этому только частично.

Наблюдаемое реальное поведение:

- `AdminAccountsService` сам выполняет `commit` и `rollback`.
- `showcase.py` пишет прямо в DB и делает `commit` в router helpers.
- `sources.py` выполняет direct updates profile и переписывание статусов products в router functions.
- `products.py` содержит extensive direct ORM mutations для manual catalog и showcase-style overrides.
- `jobs.py` напрямую сохраняет aggregate runtime и применяет product upserts.

Это важно для будущих refactors: авторитетный текущий design не является строгой layered repository architecture.

## Мягкое удаление и фильтры чтения
Значительная часть parser-catalog reads явно фильтрует `deleted_at.is_(None)`.

Ожидаемые паттерны:

- products часто soft-deleted;
- source profiles фильтруются по `deleted_at`;
- image assets для manual product images фильтруются по `deleted_at`;
- многие public/admin queries используют helper functions, чтобы оставить только active sources/products.

Поскольку правила soft-delete не enforced глобально через ORM configuration, каждый query path вручную определяет visibility.

## Межмодульная связность схемы
Таблицы backend потребляются из нескольких мест:

- `frontend` - только через HTTP responses backend;
- `service` - косвенно через API, которыми владеет backend, плюс общее присутствие DB в Compose;
- background worker читает и пишет `AdminUiSettings`;
- weight enrichment parser-service зависит от payload weight-rules, генерируемого backend, а не от прямого доступа к tables.

Главный риск связности заключается не в shared ORM code, а в shared runtime assumptions вокруг одной и той же PostgreSQL schema.

## Текущие риски слоя данных
- Большие modules service/router смешивают read models и write models в одних и тех же files.
- Владение schema централизовано в backend, но runtime ownership writes распределен между routers, services и worker code.
- Legacy tables остаются в metadata, поэтому migration planning должен учитывать исторические objects, даже если current UI flows их не используют.
- Поскольку repositories тонкие и на практике необязательны, добавление новых writes требует аккуратного review, чтобы не допустить дублирующихся правил persistence.
