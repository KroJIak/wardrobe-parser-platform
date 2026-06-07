# Архитектурная заметка по backend-модулю

## Назначение и границы
`backend` — это HTTP API-модуль платформы, расположенный в `backend/app`. В текущем коде он совмещает:

| Область | Текущая ответственность |
|---|---|
| Admin API | auth/RBAC, sources, pricing/settings, categories, dedup, sync control, manual product management |
| Public site API | публичные категории каталога, публичный листинг каталога, product detail, состояние showcase media и выдача изображений |
| Read-side enrichment | расчет цен, brand mapping, category projection, source visibility, starred category overlays |
| Service orchestration | запуск/poll/cancel sync-job, patch source config, вызовы product probe, выборочное proxying в `service` |

Границы, видимые из кода:
- `frontend` потребляет `/api/v1/...` из этого модуля.
- `service` вызывается по HTTP через `SERVICE_BASE_URL`.
- schema/migrations определены в `backend`, а не в `service`.

## Структура приложения
- Entrypoint: `app/main.py`
- Factory: `app/core/app_factory.py`
- Docs/OpenAPI: `/api/docs`, `/api/openapi.json`, отфильтрованный public OpenAPI в `/api/openapi/public.json`
- Startup hooks: `AdminAccountsService.ensure_superadmin_user()`, `mark_interrupted_jobs_on_startup()`
- Общий wiring: CORS из `CORS_ALLOWED_ORIGINS`; кастомные handlers для `NotFoundError`, `ValidationError`, `IntegrityError`

## Группы роутеров
| Файл | Область | Модель auth |
|---|---|---|
| `api/v1/auth.py` | admin login/refresh/logout, current user, roles, users | login/refresh/logout публичные, остальное защищено |
| `api/v1/categories.py` | admin category tree и public catalog category roots/branch | смешанная |
| `api/v1/dedup.py` | duplicate review flows | защищено permission |
| `api/v1/settings.py` | pricing, admin UI, supplier tariffs, weight rules, settings transfer | защищено permission |
| `api/v1/public_parser_contract.py` | public weight-rules contract для parser | публичный |
| `api/v1/showcase.py` | showcase state, image delivery, hero/carousel uploads и order changes | чтение публичное; mutation endpoints сейчас не имеют auth dependency |
| `api/v1/jobs.py` | backend-side sync orchestration поверх `service` jobs/events | защищено permission |
| `api/v1/products.py` | public product APIs, admin product APIs, manual product CRUD, image upload, proxying | смешанная |
| `api/v1/sources.py` | список источников и source/backend profile settings | защищено permission |

## Аутентификация и авторизация
- Реализованы в `services/auth/admin_auth_service.py`.
- Формат токена — кастомный HMAC-signed JWT-like payload, а не библиотечный JWT stack.
- Источники access token:
  - заголовок Bearer через `HTTPBearer`
  - cookies `admin_access_token` / `admin_refresh_token`
- Claims включают `uid`, `sub`, `type`, `iat`, `exp`, `jti`.
- Хранилище RBAC:
  - `admin_role`
  - `admin_user`
- Каталог permissions статически задан в `services/auth/permissions.py`.
- Gatekeeper-функции:
  - `require_admin_access`
  - `require_superadmin`
  - `require_permission(...)`
- Хэширование пароля: PBKDF2-SHA256 в `services/auth/passwords.py`.
- Login rate limiting использует Redis в `services/auth/login_rate_limiter.py`.
- Пользователь superadmin создается/синхронизируется из env при старте и во время проверки учетных данных.

## Основные сервисы
| Сервис | Ответственность |
|---|---|
| `AdminAccountsService` | bootstrap superadmin, CRUD ролей и пользователей |
| `PricingSettingsService` | CRUD pricing settings, CRUD suppliers/tariffs, admin UI settings, расчет final price, интеграция Bybit |
| `WeightRuleService` | seed default rules, CRUD правил, пересчет product weight, payload parser contract |
| `CategoryTreeService` | CRUD категорий, CRUD keywords, manual category-product links, sync designer branch |
| `CategoryIndexService` | rebuild предвычисленных category match/count и чтение snapshot |
| `DedupService` | генерация duplicate candidate и moderation actions |
| `BrandMappingService` | normalized vendor mapping и admin mapping payload |
| `SettingsTransferService` | export/import/reset pricing/source/category/weight/brand settings |
| `BybitP2PRateProvider` | получение и кэширование snapshot bucket/rate из Bybit P2P |

Поддерживающий runtime-код:
- `workers/bybit_rate_worker.py`: периодическое обновление Bybit плюс auto-sync loop
- `services/proxy/service_api_proxy.py`: generic HTTP forwarder в `service`

## Структура repository, model и schema
- Репозитории живут в `app/repositories` и в основном являются thin SQLAlchemy wrappers поверх одной model.
- `BaseRepository` предоставляет `create`, `get_by_id`, `query`, `flush`.
- Активные группы моделей:

| Группа | Модели |
|---|---|
| Parser catalog | `ParserSource`, `ParserProduct`, `ParserProductOriginVariant`, `ParserFavoriteProduct`, `ParserDedupDecision`, `ParserBrandMapping` |
| Categories | `ParserCategory`, `ParserCategoryKeyword`, `ParserCategoryManualProduct`, `ParserProductCategoryMatch`, `ParserCategoryCountSnapshot`, `ParserCategoryIndexState` |
| Pricing | `ParserPricingSettings`, `ParserSupplier`, `ParserSupplierShippingRate` |
| Weight | `ParserWeightRule`, `ParserWeightKeyword` |
| Admin | `AdminRole`, `AdminUser`, `AdminUiSettings` |
| Media / sync runtime | `ImageAsset`, `SyncJobRuntime`, `SyncAppliedBatch` |

- Схемы разделены на:
  - `schemas/auth.py` для auth/RBAC
  - `schemas/parser.py` для categories, catalog, settings, showcase, products, dedup
- `models/__init__.py` по-прежнему экспортирует `Product`, `ProductImage` и `Site`; в остальном проверенном backend-коде они не были использованы.

## Public API против Admin API
Public surface, явно попадающий в filtered OpenAPI:
- `GET /health`
- `GET /api/v1/catalog/categories/roots`
- `GET /api/v1/catalog/categories/root/{root_slug}`
- `GET /api/v1/catalog/products`
- `GET /api/v1/products/{product_id}`
- `GET /api/v1/products/images/{image_id}`
- `GET /api/v1/showcase/state`
- `GET /api/v1/showcase/hero/image`
- `GET /api/v1/showcase/carousel`
- `GET /api/v1/showcase/carousel/{image_id}/image`

Admin/protected surface:
- `/api/v1/auth/me`, `/auth/accounts/...`
- `/api/v1/categories/...`
- `/api/v1/dedup/...`
- `/api/v1/settings/...`
- `/api/v1/jobs...`
- `/api/v1/sources...`
- `/api/v1/admin/products...`
- product mutation/admin helper endpoints в `products.py`

## Владение базой данных и миграциями
- SQLAlchemy metadata приходит из `backend/app/models`.
- Alembic расположен в `backend/alembic`.
- Таблица версий: `alembic_version_backend`.
- По содержимому репозитория видно 36 backend revisions (`0001` до `0036`).
- `docker-compose.yml` запускает:
  - `backend-db-init`: `alembic upgrade head`
  - `service-db-init`: явный `no-op`
- Compose указывает и `backend`, и `service` на один и тот же `DATABASE_URL`, но владение миграциями остается за `backend`.

## Переменные окружения и runtime-зависимости
Ключевые config keys:
- `DATABASE_URL` или `POSTGRES_*`
- `CORS_ALLOWED_ORIGINS`
- `SERVICE_BASE_URL`
- `SERVICE_PROXY_CONNECT_TIMEOUT_SEC`
- `SERVICE_PROXY_READ_TIMEOUT_SEC`
- `REDIS_URL`
- `ADMIN_SUPERUSER_LOGIN`
- `ADMIN_SUPERUSER_PASSWORD`
- `ADMIN_ACCESS_TOKEN_TTL_SEC`
- `ADMIN_REFRESH_TOKEN_TTL_SEC`
- `ADMIN_TOKEN_SECRET`
- `ADMIN_AUTH_COOKIE_SECURE`

Domain-specific config:
- `DEDUP_*`
- `PRICING_BYBIT_*`
- `DEFAULT_FALLBACK_WEIGHT_GRAMS`
- `CATEGORY_GENDER_PROFILE_*`

Runtime-зависимости:
- PostgreSQL
- Redis
- HTTP API сервиса `service`
- внешние HTTP-вызовы в Bybit P2P и Frankfurter
- локальное upload storage в `/app/uploads/showcase` и `/app/uploads/products`

## Взаимодействие с другими модулями
С `service`:
- backend вызывает `/api/v1/sync/sources`
- backend вызывает `/api/v1/sync/jobs`, `/jobs/{id}`, `/jobs/{id}/events`, cancel endpoints
- backend вызывает `/api/v1/sync/probe/jobs...`
- backend форвардит generic `/api/v1/products...` requests через `forward_service_request()`

С `frontend`:
- admin frontend потребляет endpoints auth, admin products, sources, jobs, settings, showcase, category и dedup
- site frontend потребляет public catalog categories, catalog product list, product detail и showcase media endpoints

С `service` в обратную сторону:
- `service/app/services/weight_rules_client.py` вызывает backend `GET /api/v1/public/parser-contract/weight-rules`

## Фактические структурные наблюдения
- `api/v1/products.py` имеет 3309 строк и смешивает public reads, admin reads, admin mutations, manual product CRUD, image handling, pricing enrichment и HTTP proxy behavior.
- `api/v1/jobs.py` имеет 1709 строк и совмещает in-memory job state, polling, event translation, DB upserts, telemetry updates и запуск rebuild category index.
- `services/settings/pricing_service.py` имеет 1723 строки; `weight_rule_service.py`, `category_tree_service.py`, `category_index_service.py` и `settings_transfer_service.py` также являются крупными multi-responsibility modules.
- Layering непоследователен: repositories тонкие, но ряд routers и service-heavy endpoint все еще выполняют прямые ORM queries и commits.
- `schemas/parser.py` — это широкий общий schema file для нескольких доменов, а не набор меньших schema modules по доменам.
- Mutation endpoints в `showcase.py` сейчас не имеют auth dependency, хотя admin UI использует их как admin actions.
- Compose передает `IMAGE_PROXY_*`, `IMAGE_CACHE_*` и `IMAGE_RATE_LIMIT_PER_MINUTE`, но `core/config.py` не определяет их и игнорирует лишние env keys.
- `ADMIN_SUPERUSER_PASSWORD` и `ADMIN_TOKEN_SECRET` генерируются автоматически, если отсутствуют, поэтому стабильное auth/bootstrap behavior зависит от явной env-конфигурации.
- Текущая проверка `service/app/api/v1` показывает только `/sync` routes, тогда как backend все еще содержит generic proxy routes, нацеленные на `service` `/api/v1/products...`.
