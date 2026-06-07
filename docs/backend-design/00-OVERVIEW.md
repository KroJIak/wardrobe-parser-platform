# Архитектура Backend

## Назначение
`backend` - это основной HTTP boundary платформы. В текущей реализации он одновременно обслуживает:

- admin API для управления источниками, каталогом, категориями, дедупликацией, pricing и settings;
- публичный API витрины для категорий, каталога, карточки товара и showcase media;
- read-side enrichment поверх данных каталога;
- orchestration слой над `service` для sync jobs и части product probe flows.

Документы в этой папке описывают backend ровно в текущем виде, включая смешанные зоны ответственности и исторические слои, которые все еще присутствуют в коде.

## Границы домена
Backend напрямую взаимодействует с четырьмя внешними сторонами:

- `frontend` читает и изменяет данные только через `/api/v1/...`.
- `service` вызывается по HTTP через `SERVICE_BASE_URL`.
- PostgreSQL используется как основной persistent store и owned schema модуля backend.
- Redis используется для login rate limiting; отдельного background queue в inspected code нет.

Backend не является thin BFF. Он сам вычисляет pricing, category projections, source visibility, dedup moderation results и части showcase state.

## Внутренняя архитектура
Текущая архитектура ближе к "router-heavy monolith" с внешним parser-service:

```text
HTTP / FastAPI routers
  -> auth dependencies / request validation / partial orchestration
  -> service layer modules
  -> repositories + direct ORM queries
  -> PostgreSQL

Cross-cutting:
  -> Redis login limiter
  -> parser-service HTTP client/proxy
  -> uploads filesystem
  -> background worker for Bybit refresh + auto-sync
```

В идеальном проектном паттерне транзакции должны жить в service-слое, но в текущем коде `commit` и direct ORM work встречаются и в routers, и в service methods. Эти документы не нормализуют это поведение, а фиксируют его как факт.

## Карта routers
`app/api/v1/__init__.py` собирает один `APIRouter(prefix="/api/v1")` и подключает:

| Файл router | Основная зона | Примечания |
|---|---|---|
| `auth.py` | admin session, roles, users | custom signed token pair + cookies |
| `categories.py` | admin category tree + public category menu | mixed admin/public surface |
| `dedup.py` | duplicate review and decisions | permission-gated |
| `settings.py` | pricing, suppliers, weight, admin UI, export/import/reset | service-heavy runtime |
| `public_parser_contract.py` | public parser weight-rules contract | no admin auth |
| `showcase.py` | hero/carousel state and image upload | public reads; mutations are currently unauthenticated |
| `jobs.py` | aggregate sync orchestration over `service` | in-memory + DB runtime |
| `products.py` | public products, admin products, manual CRUD, media, proxying | biggest mixed-responsibility file |
| `sources.py` | merged view of service sources + backend source profiles | backend/service ownership split |

## Хуки запуска и runtime
`app/core/app_factory.py` настраивает процесс:

- создает FastAPI app с docs по пути `/api/docs` и OpenAPI по пути `/api/openapi.json`;
- регистрирует exception handlers для проектных `NotFoundError`, `ValidationError`, `IntegrityError`;
- настраивает CORS из `CORS_ALLOWED_ORIGINS`;
- выполняет два startup-действия:
  - `AdminAccountsService.ensure_superadmin_user()`
  - `mark_interrupted_jobs_on_startup()`
- отдает отфильтрованный public OpenAPI по пути `/api/openapi/public.json` и compatibility aliases под `/api/openapi/showcase.json`.

Public OpenAPI генерируется не из отдельного дерева routers. Он post-factum фильтруется до фиксированного allowlist публичных `GET` endpoints.

## Текущие структурные ограничения
Эти ограничения определяют остальную документацию:

- `products.py` содержит 3309 строк и смешивает public, admin, manual-catalog и proxy behavior.
- `jobs.py` содержит 1709 строк и владеет aggregate sync runtime плюс DB apply logic.
- `pricing_service.py` содержит 1723 строки и выступает как pricing engine, settings service и FX integration surface.
- Backend владеет Alembic migrations для общей PostgreSQL schema; `service` не владеет активными migrations.
- Часть public/admin boundaries существует только через dependency usage, а не через отдельные apps или отдельные router namespaces.

## Порядок чтения
1. `01-project-setup.md` - bootstrap процесса, config, Docker и app factory.
2. `02-auth-and-rbac.md` - модель session, cookies, permissions, bootstrap superadmin.
3. `03-data-layer-and-schema-ownership.md` - models, repositories, migrations, правила ownership.
4. `04-sync-and-source-orchestration.md` - контракт backend <-> parser-service и aggregate jobs.
5. `05-product-catalog-and-public-showcase.md` - основная read/write поверхность products и showcase.
6. `06-categories-dedup-and-merchandising.md` - потоки curation и moderation.
7. `07-pricing-weight-and-settings.md` - pricing и operational settings.
8. `08-runtime-workers-and-external-integrations.md` - background worker и внешние системы.
9. `09-deployment-and-operations.md` - compose topology и operational behavior.

## Индекс документов
| # | Файл | Назначение | Зависит от |
|---|---|---|---|
| 00 | `00-OVERVIEW.md` | Карта домена и порядок чтения | - |
| 01 | `01-project-setup.md` | App factory, config, runtime services | codebase root, Compose |
| 02 | `02-auth-and-rbac.md` | Admin auth, permissions, lifecycle session | 01 |
| 03 | `03-data-layer-and-schema-ownership.md` | ORM, repositories, migrations, ownership | 01 |
| 04 | `04-sync-and-source-orchestration.md` | Source registry merge и sync jobs | 01, 03 |
| 05 | `05-product-catalog-and-public-showcase.md` | HTTP-поверхность catalog/product/showcase | 03, 04, 07 |
| 06 | `06-categories-dedup-and-merchandising.md` | Функции category и moderation | 03, 05 |
| 07 | `07-pricing-weight-and-settings.md` | Pricing, weight, admin UI settings | 03 |
| 08 | `08-runtime-workers-and-external-integrations.md` | Workers, Redis, HTTP integrations, uploads | 01, 04, 07 |
| 09 | `09-deployment-and-operations.md` | Compose runtime и operational rules | 01, 08 |

## Междоменные зависимости
- С `frontend`: все admin и public HTTP interactions завершаются здесь.
- С `service`: список sync sources, sync jobs, probe flows, generic product proxying.
- Со схемой database: backend является владельцем migrations и основным writer для persistent catalog/admin state.
- С будущими API docs: эта директория соответствует backend-стороне утвержденного набора protocol `frontend--backend`, `backend--parser-service` и `backend--database`.
