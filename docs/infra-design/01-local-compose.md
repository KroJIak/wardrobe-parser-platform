# Дизайн инфраструктуры: локальный Compose

## Область применения

- Охватывает: локальную Docker Compose-топологию, порядок запуска, порты, volumes и маршрутизацию разработки.
- НЕ охватывает: hosted-переключение доменов, настройку внешнего reverse proxy или API-контракты уровня приложения.
- Зависит от: `02-ARCHITECTURE.md`, `backend-design/09-deployment-and-operations.md`.

## Топология сервисов

Локальный runtime использует следующие сервисы:

| Сервис | Роль | Внутренний порт |
|---------|------|-----------------|
| `postgres` | основная база данных | `5432` |
| `redis` | кэш и основа rate-limit | `6379` |
| `backend-db-init` | runner миграций | n/a |
| `service-db-init` | задокументированный no-op init service | n/a |
| `backend` | основной API | `8000` |
| `backend-worker` | worker обновления курса Bybit | n/a |
| `service` | parser runtime | `8000` |
| `frontend-site` | nginx-контейнер сайта | `80` |
| `frontend-admin` | nginx-контейнер admin | `80` |
| `db-admin` | Adminer (только override) | `8085` |

## Порядок запуска

Зависимости запуска в Compose сделаны намеренно явными:

1. `postgres` и `redis` становятся healthy.
2. `backend-db-init` применяет Alembic migrations.
3. `service-db-init` успешно завершается как no-op.
4. Стартует `backend`.
5. Стартует `service`.
6. `frontend-site` и `frontend-admin` стартуют после health backend.
7. `backend-worker` стартует после того, как database после миграций готова.

## Локальное отображение портов

Хост-порты по умолчанию из `.env.example`:

| Host port | Container target | Сервис |
|-----------|------------------|--------|
| `10510` | `8000` | backend |
| `10520` | `8000` | parser service |
| `10530` | `80` | frontend-site |
| `10531` | `80` | frontend-admin |
| `10540` | `5432` | postgres |
| `10550` | `8085` | Adminer |

## Тома и монтирования

| Хранилище | Подключено к | Назначение |
|---------|---------------|------------|
| `postgres_data` | postgres | долговечные данные БД |
| `redis_data` | redis | append-only persistence Redis |
| `backend_uploads` | backend | uploaded product и showcase assets |
| `./service/config:/app/config` | parser service (override) | файловый реестр источников |

## Модель локальной маршрутизации

### Браузерный трафик

- `frontend-site` отдает public site.
- `frontend-admin` отдает admin UI.
- оба proxy'ят `/api/` на `backend:8000`
- оба наследуют nginx `client_max_body_size 100m`; это фактический предел размера request body для admin uploads, идущих через frontend containers

### Внутренний трафик

- backend -> parser service использует `http://service:8000`
- parser service -> backend использует `http://backend:8000`
- backend и parser service -> database используют внутренний hostname из `POSTGRES_HOST`

## Локальная проверка работоспособности

Ожидаемые health endpoints:

| Сервис | Проверка |
|---------|----------|
| backend | `GET /health` |
| parser service | `GET /health` |
| frontend-site | nginx отдает собранный static site |
| frontend-admin | nginx отдает собранный admin SPA |

Локальный baseline считается healthy, когда Compose stack поднят, backend возвращает `{"status":"ok"}`,
parser service возвращает `{"status":"ok"}`, а оба frontend-порта отдают HTML.
