# Черновик API-слоя

## Часть A: модели данных

### Канонические файлы моделей данных
| Файл | Область сущности | Основные поставщики | Основные потребители |
|------|--------------|------------------|-------------------|
| `api/data-models/admin-account.md` | roles, users, permission lists | backend, database | frontend |
| `api/data-models/admin-session.md` | login request, session response, current user session state | backend | frontend |
| `api/data-models/source.md` | source identity, enable/sync flags, visibility, supplier/currency config | backend, parser-service, database | frontend |
| `api/data-models/parser-product.md` | curated parser product, variants, edit state, status | backend, parser-service, database | frontend |
| `api/data-models/product-preview.md` | payload preview/probe/manual product create/edit | parser-service, backend | frontend |
| `api/data-models/category.md` | admin category tree, public category tree, manual category-product links | backend, database | frontend |
| `api/data-models/dedup.md` | dedup candidate pair, dedup decision record | backend, database | frontend |
| `api/data-models/pricing-settings.md` | pricing formula и global pricing settings | backend, database | frontend |
| `api/data-models/pricing-supplier.md` | supplier и структуры supplier shipping rate | backend, database | frontend |
| `api/data-models/weight-rule.md` | weight rules, missing products view, parser weight contract | backend, parser-service, database | frontend |
| `api/data-models/showcase-state.md` | showcase hero/carousel state и linkage с image asset | backend, database | frontend |
| `api/data-models/sync-job.md` | latest job, history item, detailed runtime status | backend, parser-service, database | frontend |
| `api/data-models/sync-event.md` | event stream item и payload события product batch | parser-service, backend | backend |
| `api/data-models/brand-mapping.md` | список brand mapping и payload update | backend, database | frontend |
| `api/data-models/settings-transfer.md` | payload export/import/reset для sources, pricing, categories, brand mapping, UI settings | backend, parser-service, database | frontend |

### Общие enum (`api/data-models/enums.md`)
Черновой набор enum должен покрывать как минимум:
- permission scopes (`showcase.*`, `control.sources.*`, `control.products.*`, `control.dedup.*`, `control.categories.*`, `control.designers.*`, `control.pricing.*`, `control.weight.*`, `control.settings.*`, `accounts.*`)
- source status (`active`, `disabled`, `error`, `auth_required`)
- source product status (`available`, `out_of_stock`, `unavailable`)
- curated product status (`available`, `out_of_stock`, `hidden`, `unavailable`)
- source run status (`pending`, `in_progress`, `success`, `partial`, `failed`, `cancelled`)
- sync stage codes из parser-service contract
- supplier category (`main`, `alt`)
- final rounding mode (`none`, `unit`, `ten`, `hundred`, `thousand`)
- currency method (`priority_list`, `locked_param_currency`, `locked_no_currency`)
- category keyword scope (`local`, `title`, `status`)

## Часть B: протоколы

### `api/protocols/frontend--backend.md`
Область охвата:
- admin auth routes
- bootstrap и CRUD для admin accounts/roles
- listing sources и маршруты мутаций source
- jobs latest/history/cancel и запуск sync
- маршруты product list/detail/manual/probe/preview/image
- CRUD категорий и ручные привязки
- операции с dedup candidate/decision
- pricing/settings/weight/brand-mapping routes
- showcase state/media routes
- public showcase/catalog routes

Ключевые разделы:
1. Эндпоинты auth/session и транспорт через cookie.
2. Admin operational endpoints, сгруппированные по bounded capability.
3. Public catalog/showcase endpoints, используемые site.
4. Модель ошибок и модель отказа по правам.
5. Правила именования полей JSON payload, которые потребляет TypeScript.

### `api/protocols/backend--parser-service.md`
Область охвата:
- вызовы `backend -> parser-service` для `/api/v1/sync/sources`, `/jobs`, `/probe/jobs`, `/events`, `/cancel`
- вызов `parser-service -> backend` к `/api/v1/public/parser-contract/weight-rules`
- трансляция payload между backend aggregate job runtime и parser-service process-local job runtime
- контракт события `product_batch`, который использует backend ingestion

Ключевые разделы:
1. Source registry mirror и patch contract.
2. Контракт создания multi-source job.
3. Контракт создания и получения probe-job.
4. Контракт event stream, включая `product_batch`.
5. Public weight-rule contract, предоставляемый backend.
6. Трансляция ошибок (`502` proxy failures, `409` sync already running, parser-config errors).

### `api/protocols/backend--database.md`
Область охвата:
- семейства моделей и группы repository, которыми владеет backend
- write ownership для parser catalog, categories, pricing, auth, showcase, sync runtime
- migration lineage и source of truth для эволюции schema
- worker/runtime access patterns для Redis-backed или scheduled updates, где сохраняется DB state

Ключевые разделы:
1. Mapping `repository -> table`.
2. Матрица read/write ownership по группам таблиц.
3. Власть над транзакциями и миграциями.
4. Query patterns для catalog, settings, dedup и runtime jobs.

### `api/protocols/parser-service--database.md`
Область охвата:
- явная фиксация текущего состояния: runtime parser-service file-backed для source config и не показывает подтвержденного активного DB persistence layer в проверенном коде
- latent dependencies (`DATABASE_URL`, SQLAlchemy/Alembic packages) задокументированы как неавторитетные до реальной реализации

Ключевые разделы:
1. Подтвержденное неиспользование DB в active runtime code path.
2. Поведение file-backed persistence source config.
3. Ограничение для будущего рефакторинга: любое будущее владение DB со стороны parser-service должно быть спроектировано заново, а не выводиться из env/deps.

## Часть C: auth (`api/auth.md`)

Документ auth должен определять:
1. Admin login request/response и выпуск cookie.
2. Lifecycle access token и refresh token.
3. Silent refresh behavior во frontend при `401`.
4. Ответ `me` как текущий контракт permission/session.
5. Поведение bootstrap superadmin на старте backend.
6. Каталог permission scopes и route-level usage авторизации.

## Машины состояний, которые нужно зафиксировать
| Машина | Ключевые состояния | Владеющий домен |
|---------|------------|---------------|
| Admin session | unauthenticated -> authenticated -> refreshed -> logged_out/expired | backend + frontend |
| Source run | pending -> in_progress -> success/partial/failed/cancelled | parser-service |
| Aggregate sync job | queued -> in_progress -> completed/failed/cancelled | backend + parser-service |
| Product lifecycle | available/out_of_stock/hidden/unavailable | backend |
| Dedup decision | candidate -> merged/rejected/combined -> undoable snapshot | backend |

## Последствия для финальных docs
- Финальные `api/` docs должны рассматривать canonical data models как единственное место, где определены формы полей.
- Финальные domain docs должны ссылаться на эти модели вместо повторного описания payload встраиваемым текстом.
- Database docs должны сохранять рядом и legacy tables, и current parser tables, потому что обе поверхности существуют в проверенной schema.
