# Архитектура

## Форма системы

Платформа следует четырехчастной модели рантайма:

1. `frontend-site` и `frontend-admin` отдают независимые браузерные точки входа из одной frontend codebase.
2. `backend` — это авторитетный HTTP API и слой бизнес-оркестрации.
3. `service` — специализированный рантайм парсера для sync и probe-задач.
4. `postgres` и `redis` предоставляют общее постоянное хранилище и поддержку рантайма.

## Технологический стек

| Слой | Выбор | Почему |
|------|-------|--------|
| Web frontend | React + TypeScript + Vite + nginx | быстрый SPA-рантайм с отдельными admin/site-сборками |
| Backend API | FastAPI + Pydantic + SQLAlchemy | типизированный HTTP-слой и явные границы repository/service |
| Parser runtime | FastAPI + Python + Node + Chromium + Xvfb | поддержка и HTTP-оркестрации, и browser-driven extraction flow |
| Primary database | PostgreSQL | общий реляционный источник истины |
| Migration system | Alembic | эволюция схемы под владением backend |
| Кэш и лимиты runtime | Redis | login rate limiting и cache-backed helpers |
| Container runtime | Docker Compose | воспроизводимая локальная и hosted-топология сервисов |
| Hosted routing | Dokploy + container networking | привязка доменов site/admin к отдельным frontend-сервисам |

## Ключевые архитектурные решения

### Авторитетная граница backend

Все браузерные клиенты общаются с backend, а не напрямую с parser service или database.
Backend владеет auth, курируемым состоянием, публичными read models и orchestration над parser jobs.

### Отдельный рантайм парсера

Парсинг вынесен в отдельный сервис, потому что он требует существенно отличающегося рантайма:
source-specific adapters, browser automation, Node tooling и long-running sync jobs.

### Общая база данных с одним владельцем миграций

И backend, и parser service получают database URL, но только backend является документированным владельцем схемы.
Alembic revisions лежат в `backend/alembic`, а `backend-db-init` накатывает migrations на запуске.

### Две frontend-точки входа в одном web-модуле

Веб-слой разделен на `admin` и `site` entrypoint, но оба собираются из одного репозитория
и одного Vite workspace. Это сохраняет общий UI/runtime-код и при этом оставляет независимые deployment targets.

### Файловый реестр источников парсера

Конфигурация источников рантайма парсера принадлежит `service/config/sources.json`.
Этот реестр отделен от DB-owned curated source metadata в backend.

## Ключевые архитектурные паттерны

### Оркестрация поверх исполнения

Backend запускает sync и probe jobs, зеркалирует source flags, получает event streams и ingest'ит parser output.
Parser service исполняет source runs и публикует обновления рантайма, но не владеет пользовательскими рабочими процессами.

### Канонический слой контрактов

Директория `api/` определяет:

- общие модели данных
- auth-поведение
- протоколы между парами доменов

Этот слой контрактов — опорная точка системы для форм полей, переходов состояний и междоменных ожиданий.

### Разделение read/write по ответственности

- Backend пишет curated catalog, auth, pricing, categories, dedup, showcase и sync runtime state.
- Parser service пишет file-backed source registry и in-memory runtime state.
- Frontend не владеет постоянными данными; он владеет view state и session UX.

### Фильтрация публичной поверхности

Backend генерирует отфильтрованную публичную OpenAPI-поверхность для site-facing subset:

- catalog categories
- public catalog products
- product detail
- product images
- showcase state и media

Admin routes остаются вне этого набора публичного OpenAPI.

## Модель безопасности

### Аутентификация администратора

Admin auth использует custom HMAC-signed token pair:

- short-lived access token
- longer-lived refresh token

Tokens доставляются через bearer/cookie-compatible поведение, а browser runtime опирается на cookie transport
и silent refresh flow при `401`.

### Авторизация

Защита маршрутов строится на permission-based model.
Семейства permissions включают:

- `showcase`
- `control.sources`
- `control.products`
- `control.dedup`
- `control.categories`
- `control.designers`
- `control.pricing`
- `control.weight`
- `control.settings`
- `accounts`

### Защита рантайма

- Redis-backed login rate limiting защищает auth endpoints.
- CORS origins задаются явно через `CORS_ALLOWED_ORIGINS`.
- Frontend containers proxy'ят `/api` на backend, сохраняя same-origin-поведение в браузере.

## Архитектура развертывания

```text
browser(site)  ──► frontend-site:80 ──► backend:8000 ──► postgres:5432
browser(admin) ─► frontend-admin:80 ─► backend:8000 ──► redis:6379
                                         │
                                         └────────────► service:8000
```

Hosted и local deployment используют один и тот же набор сервисов:

- `frontend-site`
- `frontend-admin`
- `backend`
- `backend-worker`
- `service`
- `postgres`
- `redis`

## Текущие архитектурные ограничения

Это активные характеристики платформы, которые нужно считать зафиксированными фактами дизайна при рефакторинге:

- frontend contracts в основном handwritten, а не generated from OpenAPI
- большие orchestration-файлы концентрируют много логики во всех трех основных code module
- parser-service jobs хранят runtime state process-local, а не DB-backed
- source ownership split между file-backed parser config и DB-backed backend metadata
- latent DB dependencies существуют в parser service environment без active documented DB write path

## Карта чтения

- Для frontend behavior: `frontend-design/`
- Для auth и contracts: `api/auth.md` и `api/protocols/frontend--backend.md`
- Для backend orchestration: `backend-design/`
- Для parser execution: `parser-service-design/`
- Для persistent ownership: `database-schema/`
- Для топологии рантайма и deployment: `infra-design/`
- Для поверхностей рядом с репозиторием, не входящих в runtime: `repo-auxiliary/`
