# Архитектура Backend: Настройка проекта

## Область
- Покрывает: bootstrap backend-процесса, package/runtime dependencies, модель конфигурации, Docker entrypoints, wiring app factory.
- Не покрывает: бизнес-правила для auth, catalog, sync, pricing или category logic.
- Зависит от: `00-OVERVIEW.md`.

## Структура репозитория
Модуль backend расположен в `backend/` и представляет собой standalone FastAPI service.

Ключевые директории:

| Путь | Назначение |
|---|---|
| `backend/app/main.py` | минимальный module entrypoint, экспортирует `app = create_app()` |
| `backend/app/core/` | config, database wiring, app factory, exceptions |
| `backend/app/api/v1/` | HTTP routers |
| `backend/app/services/` | код service-layer и external integrations |
| `backend/app/repositories/` | thin SQLAlchemy wrappers |
| `backend/app/models/` | ORM models, собранные в `Base.metadata` |
| `backend/app/schemas/` | Pydantic request/response models |
| `backend/alembic/` | migration environment и revisions |
| `backend/uploads/` | runtime filesystem storage внутри container |

## Путь загрузки
Точка входа runtime намеренно остается тонкой:

```text
uvicorn app.main:app
  -> app.main imports create_app()
  -> app.core.app_factory.create_app()
  -> startup hooks run
  -> /api/v1 routers attached
```

`backend/Dockerfile` использует `python:3.12-slim`, устанавливает `curl`, устанавливает `requirements.txt`, копирует весь модуль и запускает `uvicorn`.

## Зависимости Python
`backend/requirements.txt` намеренно небольшой и сфокусирован на runtime:

- `fastapi`, `uvicorn[standard]`
- `sqlalchemy`, `psycopg2-binary`, `alembic`
- `pydantic`, `pydantic-settings`
- `requests`, `redis`, `Pillow`, `python-multipart`
- `pytest`, `httpx`

В этом модуле отсутствуют async ORM, client message broker или runtime job queue.

## Фабрика приложения
`app/core/app_factory.py` владеет всей общей wiring FastAPI.

### Что делает `create_app()`
- создает `FastAPI(title="Wardrobe Parser Backend API")`;
- публикует:
  - docs: `/api/docs`
  - OpenAPI: `/api/openapi.json`
  - public OpenAPI: `/api/openapi/public.json`
  - public docs aliases: `/api/docs/public`, `/api/redoc/public`
  - showcase compatibility aliases: `/api/openapi/showcase.json`, `/api/docs/showcase`, `/api/redoc/showcase`
  - public markdown download: `/api/docs/public.md`
- регистрирует health endpoint по пути `/health`;
- подключает `api_router`;
- устанавливает project exception handlers и CORS middleware.

### Хуки запуска
Два startup-действия выполняются синхронно:

1. открыть DB session и выполнить `AdminAccountsService.ensure_superadmin_user()`;
2. вызвать `mark_interrupted_jobs_on_startup()` из `jobs.py`.

Это означает, что сам HTTP-процесс отвечает и за auth bootstrap, и за recovery sync-runtime.

## Генерация public OpenAPI
Backend хранит единое дерево routers и получает public docs фильтрацией полной schema.

Пути в allowlist:

- `/health`
- `/api/v1/catalog/categories/roots`
- `/api/v1/catalog/categories/root/{root_slug}`
- `/api/v1/catalog/products`
- `/api/v1/products/{product_id}`
- `/api/v1/products/images/{image_id}`
- `/api/v1/showcase/state`
- `/api/v1/showcase/hero/image`
- `/api/v1/showcase/carousel`
- `/api/v1/showcase/carousel/{image_id}/image`

Фильтр также удаляет неиспользуемые component schemas и tags. Поэтому public docs являются представлением того же codebase, а не отдельно versioned contract bundle.

## Модель конфигурации
`app/core/config.py` определяет единый объект `Settings`, основанный на Pydantic Settings.

### Базовые database и network settings
- `DATABASE_URL`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`
- `CORS_ALLOWED_ORIGINS`
- `SERVICE_BASE_URL`
- `SERVICE_PROXY_CONNECT_TIMEOUT_SEC`
- `SERVICE_PROXY_READ_TIMEOUT_SEC`
- `REDIS_URL`

### Доменные settings
- dedup: `DEDUP_*`
- pricing/Bybit: `PRICING_BYBIT_*`
- weight fallback: `DEFAULT_FALLBACK_WEIGHT_GRAMS`
- auth/session: `ADMIN_*`
- category gender profile heuristics: `CATEGORY_GENDER_PROFILE_*`

### Важные особенности config
- если `DATABASE_URL` отсутствует, он собирается из `POSTGRES_*`;
- если `ADMIN_SUPERUSER_PASSWORD` отсутствует, генерируется случайный пароль;
- если `ADMIN_TOKEN_SECRET` отсутствует, генерируется случайный signing secret;
- лишние env vars игнорируются, потому что `extra="ignore"`.

Последний пункт важен операционно: Compose сейчас передает несколько `IMAGE_PROXY_*`, `IMAGE_CACHE_*` и env vars для rate-limit, которые не объявлены в `Settings`, поэтому backend молча их игнорирует.

## Подключение базы данных
`app/core/database.py` определяет:

- `engine = create_engine(settings.database_url)`
- `SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)`
- `Base = declarative_base()`
- dependency `get_db()`, которая выдает одну SQLAlchemy session на request

Проект использует синхронный SQLAlchemy и синхронные FastAPI handlers для большинства flows.

## Отображение ошибок
Project-specific exceptions нормализуются в app factory:

| Исключение | HTTP status |
|---|---|
| `NotFoundError` | `404` |
| `ValidationError` | `400` |
| `IntegrityError` | `409` |

Routers также напрямую поднимают `HTTPException` для многих domain validation failures.

## Локальный и container runtime
Compose запускает backend после того, как:

- healthcheck PostgreSQL проходит;
- `backend-db-init` завершает `alembic upgrade head`;
- healthcheck Redis проходит.

Контейнер runtime:

- публикует внутренний port `8000`;
- монтирует `backend_uploads` в `/app/uploads`;
- использует `/health` для healthcheck;
- перезапускается с политикой `unless-stopped`.

## Замечания по настройке для инженеров
- Стабильное auth-поведение требует явных `ADMIN_SUPERUSER_PASSWORD` и `ADMIN_TOKEN_SECRET`; иначе каждый fresh runtime может генерировать новые значения.
- Поскольку `Settings` читает `.env` из repo root, если он существует, и local runs, и Compose runs опираются на одну и ту же схему именования env.
- Backend-процесс не является stateless: uploads живут на диске, а recovery sync runtime читает persisted state из PostgreSQL.
