# Дизайн инфраструктуры: операции и secrets

## Область применения

- Охватывает: runtime secrets, health monitoring, постоянное хранилище, резервные копии и операционные safeguards.
- НЕ охватывает: поведение application features или business rules на уровне отдельных endpoint.
- Зависит от: `01-local-compose.md`, `02-hosted-dokploy-and-networking.md`, `api/auth.md`.

## Инвентарь secrets

| Secret / sensitive input | Используется в | Назначение |
|--------------------------|----------------|------------|
| `POSTGRES_PASSWORD` | postgres, backend, service | аутентификация в database |
| `ADMIN_SUPERUSER_PASSWORD` | backend | bootstrap admin access |
| `ADMIN_TOKEN_SECRET` | backend | подпись token |
| `REDIS_URL` | backend | runtime cache / основа rate-limit |
| Bybit pricing env vars | backend-worker, backend | интеграция с внешним pricing source |

Операционное правило: все secrets должны передаваться через environment configuration и никогда не коммититься в git.

## Требования к persistence

| Ресурс | Почему должен сохраняться |
|--------|---------------------------|
| PostgreSQL data | все curated и operational state |
| Redis append-only data | continuity runtime cache и limiter |
| backend uploads | continuity product/showcase images |
| parser `config/sources.json` | continuity parser source registry |

## Проверки работоспособности и runtime

Минимальные runtime-checks:

- backend `GET /health`
- parser service `GET /health`
- readiness PostgreSQL
- ping Redis
- успешное выполнение `backend-db-init`

Операционные проверки, которые полезно автоматизировать:

- admin login по-прежнему работает после deploy
- backend может получить latest parser-service events
- frontend `/api` proxy healthy и из site-container, и из admin-container
- каталог uploads остается writable

## Приоритеты резервного копирования

Порядок резервного копирования:

1. PostgreSQL
2. backend uploads volume
3. parser `config/sources.json`

Redis persistence полезен для continuity, но не заменяет резервные копии базы данных.

## Операционные ограничения

Текущий runtime имеет явные ограничения, которые operations должны учитывать:

- parser-service job state process-local и может потеряться при перезапуске
- source registry file-backed, а не DB-backed
- backend владеет schema upgrades; нельзя запускать ad hoc parser-service migrations как будто они authoritative
- frontend containers предполагают runtime reachability backend для всего API traffic

## Рекомендуемая процедура изменений

При изменении инфраструктуры:

1. обновить значения environment
2. подтвердить volume mounts
3. сначала перезапустить непубличные зависимости
4. прогнать migrations через `backend-db-init`
5. перезапустить backend и parser service
6. frontend containers перезапустить последними
7. проверить site, admin и health endpoints
