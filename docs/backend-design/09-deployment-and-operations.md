# Архитектура Backend: Развертывание и Эксплуатация

## Область
- Покрывает: топологию Compose, порядок инициализации, ожидания по env, healthchecks, порты, постоянные тома, эксплуатационные caveats.
- Не покрывает: детальную семантику функций, уже задокументированную в других местах.
- Зависит от: `01-project-setup.md`, `08-runtime-workers-and-external-integrations.md`.

## Топология выполнения
Проверенная локальная и hosted-топология основана на Docker Compose и включает:

- `postgres`
- `redis`
- `backend-db-init`
- `service-db-init`
- `backend`
- `backend-worker`
- `service`
- `frontend-site`
- `frontend-admin`
- опциональный `db-admin` в override

Следовательно, backend - это один runtime-сервис плюс один вспомогательный worker-сервис.

## Порядок запуска
Критическая последовательность запуска backend:

```text
postgres healthy
  -> backend-db-init runs alembic upgrade head
  -> redis healthy
  -> backend starts
  -> backend-worker starts
```

`service-db-init` намеренно является no-op и существует только для явной фиксации разделенного ownership в Compose.

## Порты и exposure
Внешние порты по умолчанию из `.env.example`:

- backend: `10510`
- service: `10520`
- site frontend: `10530`
- admin frontend: `10531`
- db admin: `10550`

Внутри сети backend слушает `8000`.

## Проверки работоспособности
Healthcheck backend:

```text
curl -f http://localhost:8000/health
```

Тот же паттерн используется для `service`.

Операционное следствие: успешный healthcheck backend подтверждает только то, что HTTP-процесс жив, но не то, что parser-service, Redis, storage media или внешние integrations pricing тоже healthy.

## Ожидания по environment
Минимальный стабильный deployment backend должен явно задавать:

- `DATABASE_URL` или все `POSTGRES_*`
- `CORS_ALLOWED_ORIGINS`
- `SERVICE_BASE_URL`
- `REDIS_URL`
- `ADMIN_SUPERUSER_LOGIN`
- `ADMIN_SUPERUSER_PASSWORD`
- `ADMIN_TOKEN_SECRET`
- `ADMIN_ACCESS_TOKEN_TTL_SEC`
- `ADMIN_REFRESH_TOKEN_TTL_SEC`

Рекомендуемые дополнительные settings зависят от включенных features:

- `PRICING_BYBIT_*`
- `DEFAULT_FALLBACK_WEIGHT_GRAMS`
- `CATEGORY_GENDER_PROFILE_*`
- `ADMIN_AUTH_COOKIE_SECURE`

### Важный эксплуатационный caveat
Если `ADMIN_SUPERUSER_PASSWORD` или `ADMIN_TOKEN_SECRET` не заданы, backend генерирует random values во время runtime. Это допустимо для ad-hoc utility runs, но небезопасно для стабильного deployment, потому что:

- пароль bootstrap superadmin становится непредсказуемым;
- secret signing tokens может меняться между fresh environments.

## Постоянное хранение
Compose сохраняет:

- данные PostgreSQL в `postgres_data`
- данные Redis в `redis_data`
- uploads backend в `backend_uploads`

Без `backend_uploads` пути к showcase/manual image assets, сохраненные в DB, после замены container будут указывать на отсутствующие files.

## Характеристики deployment
Текущая архитектура имеет несколько операционных последствий:

- web-процесс backend владеет восстановлением при запуске и создает polling threads sync;
- `backend-worker` владеет периодическим refresh Bybit и scheduling auto-sync;
- parser-service остается обязательной dependency для registry sources и фактического выполнения sync;
- hosting media локален storage backend и не делегирован object storage.

## Известные mismatches и риски
- Compose передает env vars, связанные с images, которые settings backend не распознают, поэтому операторы могут считать, что knobs существуют, хотя backend их игнорирует.
- Public mutation routes showcase опубликованы в code без auth dependencies, поэтому, если endpoint должен быть admin-only, важна изоляция сети на уровне deployment.
- `GET /api/v1/products` по-прежнему зависит от compatibility behavior с parser-service, хотя public catalog site использует local endpoints backend.
- Active state sync лишь частично durable; restarts process восстанавливают latest status runtime, но не полноценную resumable polling session.

## Практический operational checklist
- Запускайте migrations backend только из `backend/alembic`.
- Держите `backend` и `backend-worker` на одной env baseline для pricing и DB access.
- Сохраняйте `/app/uploads` для containers backend.
- Задавайте явные admin secrets в non-ephemeral environments.
- Считайте availability parser-service обязательной предпосылкой для управления sources и контроля sync, даже если public reads products могут продолжаться из DB backend.
