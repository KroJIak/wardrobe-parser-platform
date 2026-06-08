# Дизайн инфраструктуры

## Назначение

Эта директория описывает, как платформа собирается, связывается, публикуется и эксплуатируется как многоконтейнерная система.
Она охватывает локальный запуск через Compose, hosted deployment в Dokploy, маршрутизацию рантайма, secrets и операционное хранилище.

## Слои инфраструктуры

```text
Layer 4: Browser entrypoints     - домены site и admin
Layer 3: Web serving containers  - frontend-site и frontend-admin на базе nginx
Layer 2: Application services    - backend, backend-worker, parser service
Layer 1: State services          - PostgreSQL, Redis, файловая конфигурация источников, volume uploads
```

## Ключевые правила проектирования

- Frontend traffic завершается в отдельных контейнерах site/admin.
- Оба frontend-контейнера proxy'ят `/api` на backend, чтобы браузерный трафик оставался same-origin.
- Backend владеет выполнением schema migrations.
- Parser source config не получает отдельного persistent volume в базовом compose автоматически; для реальной долговечности `/app/config` нужен override bind mount или hosted volume.
- Внутреннее взаимодействие между сервисами использует имена контейнеров в сети, а не внешние host-порты.

## Индекс документов

| # | Файл | Назначение | Зависит от |
|---|------|------------|------------|
| 00 | `00-OVERVIEW.md` | этот файл | - |
| 01 | `01-local-compose.md` | локальная топология сервисов и модель портов | `02-ARCHITECTURE.md` |
| 02 | `02-hosted-dokploy-and-networking.md` | hosted-маршрутизация и привязка доменов | `01-local-compose.md` |
| 03 | `03-operations-and-secrets.md` | secrets, постоянное хранилище, health и резервные копии | `01-local-compose.md` |

## Междоменные зависимости

- `backend-design/09-deployment-and-operations.md`
- `parser-service-design/01-project-setup-and-runtime-dependencies.md`
- `frontend-design/01-project-setup.md`
- `api/auth.md`
