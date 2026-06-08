# Дизайн инфраструктуры: hosted Dokploy и сеть

## Область применения

- Охватывает: публикацию сервисов, внутренние порты, привязку доменов и ожидания от сети контейнеров в hosted deployment.
- НЕ охватывает: provider-specific provisioning виртуальных машин или CI/CD pipelines вне container runtime.
- Зависит от: `01-local-compose.md`, `02-ARCHITECTURE.md`.

## Карта hosted-сервисов

Hosted-топология повторяет local Compose и должна сохранять те же internal ports:

| Сервис | Внутренний порт | Публикация |
|---------|-----------------|------------|
| `frontend-site` | `80` | public HTTP для минимального site |
| `frontend-admin` | `80` | public HTTP для admin/showcase SPA |
| `backend` | `8000` | по умолчанию внутренний, при необходимости может быть public |
| `service` | `8000` | только internal |
| `postgres` | `5432` | только internal |
| `redis` | `6379` | только internal |

## Маршрутизация доменов

Рекомендуемая схема:

| Домен | Сервис | Внутренний порт |
|--------|--------|-----------------|
| `antonshell.com` | `frontend-site` | `80` |
| `admin.antonshell.com` | `frontend-admin` | `80` |

Поскольку frontend-контейнеры proxy'ят `/api` к backend по internal network,
браузерные клиенты в baseline deployment не требуют отдельного public API hostname.

## Правила сети

- Используйте внутренние имена сервисов для container-to-container traffic.
- Держите PostgreSQL и Redis приватными внутри project network.
- Держите parser service private, если не появится осознанная operational need.
- Подключайте persistent storage для uploads и parser source config. Для `service/config` это нужно добавить отдельно: базовый compose не создает named volume для этого пути.

## Допущения про reverse proxy

Frontend containers завершают HTTP traffic через nginx.
Слой nginx отвечает за:

- раздачу static assets
- SPA fallback handling
- proxy `/api/` на `backend:8000`
- применение текущего upload limit `client_max_body_size 100m`

Даже минимальный `frontend-site` сейчас использует тот же nginx-pattern и тоже сохраняет `/api` proxy, хотя само site-приложение пока рендерит только одну landing-страницу.

Dokploy должен направлять каждый домен напрямую на соответствующий frontend container,
а не на один общий combined web service.

## Входные данные hosted-окружения

Как минимум нужно передать:

- PostgreSQL credentials и hostname
- Redis URL
- backend admin bootstrap credentials
- backend token secret
- parser service `BACKEND_BASE_URL`
- backend `SERVICE_BASE_URL`
- allowed CORS origins, согласованные с public domains

## Проверки целостности deployment

Перед тем как принимать hosted rollout:

1. `frontend-site` отвечает на `antonshell.com`.
2. `frontend-admin` отвечает на `admin.antonshell.com`.
3. frontend `/api` traffic успешно доходит до backend.
4. backend может достучаться до parser service по internal network.
5. file uploads переживают перезапуск.
6. parser source config переживает перезапуск.
