# Внутреннее устройство доменов

## Домен: frontend-design

### План файлов
| # | Файл | Назначение | Покрывает | НЕ покрывает | Ссылки | Оценка строк |
|---|------|---------|--------|---------------|-----------|-----------|
| 00 | 00-OVERVIEW.md | Обзор домена | архитектуру, индекс, порядок чтения | детали протоколов | `api/*` | 180 |
| 01 | 01-project-setup.md | Настройка build/runtime | Vite modes, Docker, nginx, entrypoints, env vars | поведение страниц | `api/auth.md` | 180 |
| 02 | 02-app-entrypoints-and-routing.md | Композиция runtime app | `apps/admin`, `apps/site`, routers, route guards | internals fetch/state | `api/auth.md` | 220 |
| 03 | 03-shared-types-and-transformers.md | Локальный слой типов | `live-data-types`, `admin-types`, formatters, naming conversions | каталог endpoint | `api/data-models/*` | 220 |
| 04 | 04-auth-and-session-flow.md | Обработка admin session | login, refresh, logout, permission checks, protected routes | settings/business flows | `api/auth.md`, `api/protocols/frontend--backend.md` | 200 |
| 05 | 05-data-access-and-live-context.md | Слой orchestration данных | `LiveDataProvider`, композицию hooks, polling, refresh patterns | детали tab UI | `api/protocols/frontend--backend.md` | 260 |
| 06 | 06-admin-shell-and-tab-orchestration.md | Архитектура admin shell | `AdminApp`, `AdminPage`, tab dispatch, overlays, toasts | глубокие payload feature | `api/data-models/admin-session.md` | 220 |
| 07 | 07-admin-catalog-moderation-and-categories.md | UX продуктов, dedup и категорий | tables, filters, manual edit/create, dedup views, category editor | pricing/settings | `api/data-models/parser-product.md`, `api/data-models/category.md`, `api/data-models/dedup.md` | 280 |
| 08 | 08-admin-sources-pricing-weight-and-settings.md | UI операционных контролов | sources, pricing, weight, brand mapping, export/import, showcase | shell/auth/build setup | `api/data-models/source.md`, `pricing-settings.md`, `weight-rule.md`, `settings-transfer.md`, `showcase-state.md` | 300 |
| 09 | 09-public-site-runtime.md | Текущее состояние public site | placeholder runtime, dormant catalog/product implementation, current coupling к admin/shared | backend implementation | `api/protocols/frontend--backend.md` | 220 |
| 10 | 10-ui-styling-and-static-assets.md | Слой представления и assets | global styles, static assets, nginx behavior | business state | none | 160 |

### Ключевые правила проектирования
- Домен frontend ссылается на canonical payloads из `api/data-models/`; он не переопределяет backend truth.
- Authenticated data access идет через задокументированные session helpers и provider/hook layers.
- `admin` и `site` — отдельные runtime entrypoints, но их source trees пока не полностью изолированы.

## Домен: backend-design

### План файлов
| # | Файл | Назначение | Покрывает | НЕ покрывает | Ссылки | Оценка строк |
|---|------|---------|--------|---------------|-----------|-----------|
| 00 | 00-OVERVIEW.md | Обзор домена | карту слоев, индекс документов, междоменные зависимости | полные детали endpoint | `api/*`, `database-schema/*` | 180 |
| 01 | 01-project-setup.md | Настройка runtime | app factory, config, env vars, Docker/runtime services | business rules | `api/auth.md` | 180 |
| 02 | 02-auth-and-rbac.md | Граница auth | cookies, token pair, `me`, roles/users, permission scopes, bootstrap superadmin | internals catalog/settings | `api/auth.md`, `api/data-models/admin-account.md` | 240 |
| 03 | 03-data-layer-and-schema-ownership.md | Граница персистентности | SQLAlchemy models, repositories, ownership migrations, write boundaries | internals parser-service | `database-schema/*` | 260 |
| 04 | 04-sync-and-source-orchestration.md | Surface управления sync | source listing, flag patching, service proxying, jobs latest/cancel, ingest pipeline | public showcase | `api/protocols/backend--parser-service.md`, `source.md`, `sync-job.md` | 320 |
| 05 | 05-product-catalog-and-public-showcase.md | Основной surface каталога | public catalog endpoints, product detail, manual product workflows, image/media handling, showcase APIs | pricing configuration | `parser-product.md`, `product-preview.md`, `showcase-state.md` | 320 |
| 06 | 06-categories-dedup-and-merchandising.md | Features курации | categories, manual product assignment, dedup candidate/decision flows, brand mapping | auth/settings | `category.md`, `dedup.md`, `brand-mapping.md` | 280 |
| 07 | 07-pricing-weight-and-settings.md | Surface операционной конфигурации | pricing, suppliers, weight rules, admin UI settings, settings export/import/reset | parser execution details | `pricing-settings.md`, `pricing-supplier.md`, `weight-rule.md`, `settings-transfer.md` | 300 |
| 08 | 08-runtime-workers-and-external-integrations.md | Поддержка background/runtime | Redis/image cache behavior, Bybit pricing worker, parser weight contract, error mapping | frontend state | `api/protocols/backend--parser-service.md` | 220 |
| 09 | 09-deployment-and-operations.md | Модель deployment | compose topology, volumes, healthchecks, ports, Dokploy mapping assumptions | low-level DB DDL | top-level architecture docs | 180 |

### Ключевые правила проектирования
- Backend — авторитетная business/API boundary и для admin, и для public web surfaces.
- Миграциями БД владеет backend; parser-service не владеет активными schema migrations в проверенном runtime.
- Cross-service sync behavior документируется через протоколы `backend--parser-service`, а не через frontend docs.

## Домен: parser-service-design

### План файлов
| # | Файл | Назначение | Покрывает | НЕ покрывает | Ссылки | Оценка строк |
|---|------|---------|--------|---------------|-----------|-----------|
| 00 | 00-OVERVIEW.md | Обзор домена | архитектуру, индекс, execution model | полный каталог adapters | `api/protocols/backend--parser-service.md` | 180 |
| 01 | 01-project-setup-and-runtime-dependencies.md | Настройка runtime | FastAPI bootstrap, env vars, Docker, Node/Chromium/Xvfb, packaging browser runner | source-specific rules | top-level architecture | 200 |
| 02 | 02-source-registry-and-configuration-model.md | Владение source config | `config/sources.json`, `SourceRepository`, patch semantics, shapes strategy config | backend DB source profile | `api/data-models/source.md` | 240 |
| 03 | 03-sync-api-and-orchestrator-runtime.md | HTTP/runtime entrypoints | sync/probe routes, job creation, event streaming, cancellation, in-memory runtime state | per-source normalization | `api/protocols/backend--parser-service.md`, `sync-job.md`, `sync-event.md` | 280 |
| 04 | 04-source-run-pipeline.md | Flow выполнения по одному источнику | validation, discovery, strategy execution, normalization, coverage logic, reports | internals adapter registry | `parser-product.md`, `product-preview.md`, `weight-rule.md` | 280 |
| 05 | 05-adapters-and-strategy-selection.md | Модель расширяемости | adapter contract, strategy contract, registry/factory wiring, source families | детали реализации browser runner | `source.md`, `parser-product.md` | 240 |
| 06 | 06-browser-runner-and-automation.md | Browser-based parsing path | `browser_runner`, scenarios, extension bridge, JSON export contract | backend ingestion | `product-preview.md` | 220 |
| 07 | 07-backend-contracts-and-weight-enrichment.md | Контракт внешней интеграции | backend weight-rules fetch, payload dependencies, expectations source patch mirroring | DB schema | `api/protocols/backend--parser-service.md`, `weight-rule.md` | 220 |
| 08 | 08-observability-reports-and-operational-limits.md | Runtime diagnostics | run reports, events, retries, process-local limits, failure modes | UI presentation | `sync-job.md`, `sync-event.md` | 220 |

### Ключевые правила проектирования
- Документация parser-service рассматривает runtime парсинга источников как специализированный execution domain, а не как общий catalog API.
- Владение source registry file явно отделено от backend-curated source metadata.
- In-memory runtime state и browser-runner dependencies являются первоклассными задокументированными ограничениями.

## Домен: database-schema

### План файлов
| # | Файл | Назначение | Покрывает | НЕ покрывает | Ссылки | Оценка строк |
|---|------|---------|--------|---------------|-----------|-----------|
| 00 | 00-overview.md | Обзор schema | карту таблиц, write ownership, access matrix, группы migration history | detail DDL по каждой таблице | `api/data-models/*` | 220 |
| 01 | 01-parser-catalog-core.md | Core parser catalog tables | `parser_source`, `parser_product`, favorites, origin variants, image assets, source/product operational flags | admin auth tables | `source.md`, `parser-product.md` | 280 |
| 02 | 02-categories-pricing-and-merchandising.md | Таблицы курации и коммерции | categories, keywords, matches, suppliers, pricing settings, weight rules, brand mapping, admin UI settings, showcase fields | runtime jobs/auth | `category.md`, `pricing-settings.md`, `pricing-supplier.md`, `weight-rule.md`, `brand-mapping.md`, `showcase-state.md` | 320 |
| 03 | 03-admin-auth-and-sync-runtime.md | Таблицы operational auth/runtime | admin roles/users, sync job runtime, sync applied batches | legacy site/product tables | `admin-account.md`, `sync-job.md` | 240 |
| 04 | 04-legacy-ingest-tables.md | Legacy segment schema | `sites`, `products`, `product_images` и их связь с current parser catalog | runtime parser-service | `parser-product.md` | 200 |

### Ключевые правила проектирования
- Database docs описывают текущую общую schema ровно такой, какой она является, включая legacy tables, которые все еще существуют.
- Write ownership должно быть явным для каждой таблицы или группы таблиц.
- Backend migrations — это каноническая история эволюции schema.
