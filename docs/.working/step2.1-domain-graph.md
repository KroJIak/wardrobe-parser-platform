# Граф доменов

## Домены
| Каталог домена | Назначение | Технологический стек | Сложность | Чем владеет |
|-----------------|---------|-----------|-----------|------|
| frontend-design | Web runtime для entrypoints admin panel и public site | React, TypeScript, Vite, nginx | complex (10 files) | client routing, session UX, view models, browser-side orchestration |
| backend-design | Авторитетный API и business orchestration для admin/public surfaces | FastAPI, SQLAlchemy, Pydantic, Redis | complex (9 files) | auth/RBAC, catalog curation, categories, dedup, pricing, settings, showcase, sync ingestion |
| parser-service-design | Source execution engine для parse/sync/probe workflows | FastAPI, Python, Node, Chromium, Xvfb | complex (8 files) | runtime парсинга источников, source config file, in-memory sync/probe jobs, run reports |
| database-schema | Persistent data model для curated/admin/runtime state | PostgreSQL, Alembic | complex (4 files) | tables, indexes, constraints, migration lineage |

## Матрица взаимодействия доменов
|              | Frontend | Backend | Parser Service | Database |
|--------------|----------|---------|----------------|----------|
| Frontend     | -        | REST ✅ | ✗              | ✗        |
| Backend      | REST ✅  | -       | REST ✅        | SQL ✅   |
| Parser Service | ✗      | REST ✅ | -              | file-backed config + активный DB contract пока не задокументирован ⚠️ |
| Database     | ✗        | SQL ✅  | ⚠️ только latent env/dependency | - |

Легенда:
- `✅` = прямое реализованное взаимодействие, требующее protocol file
- `✗` = прямое взаимодействие не обнаружено
- `⚠️` = runtime/dependency существует, но проверенный код не показывает активный first-class protocol

## Диаграмма взаимодействия доменов (ASCII)
```text
                 ┌──────────────────────┐
                 │   frontend-design    │
                 │ admin + site web UX  │
                 └──────────┬───────────┘
                            │
                    same-origin REST
                            │
                 ┌──────────▼───────────┐
                 │    backend-design    │
                 │ auth + catalog + ops │
                 └───────┬───────┬──────┘
                         │       │
              internal REST      │ SQLAlchemy / SQL
                         │       │
              ┌──────────▼───┐   ▼
              │ parser-      │ ┌─────────────────┐
              │ service-     │ │ database-schema │
              │ design       │ │ PostgreSQL      │
              └──────────────┘ └─────────────────┘
```

## Канонические модели данных (`api/data-models/`)
| Сущность | Домены, которые ее используют | Канонический файл |
|--------|---------------------|----------------|
| Admin account и role | frontend, backend, database | `api/data-models/admin-account.md` |
| Admin session | frontend, backend | `api/data-models/admin-session.md` |
| Source | frontend, backend, parser-service, database | `api/data-models/source.md` |
| Parser product | frontend, backend, parser-service, database | `api/data-models/parser-product.md` |
| Product preview/manual draft | frontend, backend, parser-service | `api/data-models/product-preview.md` |
| Category | frontend, backend, database | `api/data-models/category.md` |
| Dedup candidate и decision | frontend, backend, database | `api/data-models/dedup.md` |
| Pricing settings | frontend, backend, database | `api/data-models/pricing-settings.md` |
| Pricing supplier | frontend, backend, database | `api/data-models/pricing-supplier.md` |
| Weight rule | frontend, backend, parser-service, database | `api/data-models/weight-rule.md` |
| Showcase state | frontend, backend, database | `api/data-models/showcase-state.md` |
| Sync job status | frontend, backend, parser-service, database | `api/data-models/sync-job.md` |
| Sync event | backend, parser-service | `api/data-models/sync-event.md` |
| Brand mapping | frontend, backend, database | `api/data-models/brand-mapping.md` |
| Settings transfer payload | frontend, backend, parser-service, database | `api/data-models/settings-transfer.md` |

## Protocols пар доменов (`api/protocols/`)
| Protocol file | Домены | Тип канала | Что передается |
|--------------|---------|-------------|-------------|
| `protocols/frontend--backend.md` | frontend ↔ backend | REST + cookie session | admin/public endpoints, payloads, errors |
| `protocols/backend--parser-service.md` | backend ↔ parser-service | internal REST | source mirror, sync jobs, probe jobs, events, weight-rule contract |
| `protocols/backend--database.md` | backend ↔ database | ORM/SQL | все паттерны персистентности curated/admin/runtime |
| `protocols/parser-service--database.md` | parser-service ↔ database | задокументированное отсутствие / latent dependency | явная фиксация, что активный DB contract в проверенном service-коде не реализован |

## Сквозные документы
| Файл | Назначение |
|------|---------|
| `api/auth.md` | admin cookie auth, refresh flow, permission model, protected-route behavior |
| `api/data-models/enums.md` | общие enum: permissions, source/product/job statuses, sync stages, supplier category, pricing modes |

## Специальные каталоги
| Каталог | Назначение |
|-----------|---------|
| `api/` | канонический source of truth для cross-domain contracts |
| `database-schema/` | группы таблиц, write ownership, access patterns |
| `.working/` | промежуточные артефакты вывода архитектуры |

## Порядок реализации
### Wave 1
- Контракты `api/` и определения `database-schema/`.

### Wave 2
- `parser-service-design` и `backend-design`, потому что именно они определяют runtime и persistence contracts, которые затем потребляет web layer.

### Wave 3
- `frontend-design`, потому что он зависит от утвержденных auth, payload, job, product и settings contracts.

### Wave 4
- Cross-domain validation, integration и планирование рефакторинга относительно утвержденных docs.
