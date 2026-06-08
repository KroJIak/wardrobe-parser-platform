# Проектирование фронтенда

## Охват
- Охватывает: текущий рантайм фронтенда, структуру исходников, схему сборки и деплоя, композицию приложений, auth-поток, архитектуру admin-shell, минимальный site-runtime, стили и ассеты.
- Не охватывает: бизнес-правила backend, внутреннее устройство parser-service, владение схемой базы данных.
- Зависит от: дерева исходников `frontend/`, `docs/.working/frontend-analysis.md`, `docs/.working/step2.2-domain-internals.md`.

## Назначение
Сабмодуль `frontend` представляет собой один проект Vite, который выпускает два отдельных браузерных приложения:
- `admin`: основной рабочий интерфейс. В него входят login, `control`-вкладки и showcase-маршруты `/`, `/catalog`, `/category/:slug`, `/product/:id`.
- `site`: отдельный изолированный сайт, который сейчас рендерит только одну страницу с фразой `be monki`.

Оба приложения собираются из одной кодовой базы, но активная глубина реализации у них разная:
- `admin` использует `react-router-dom`, глобальный `LiveDataProvider`, auth-flow и почти весь функциональный код модуля.
- `site` не использует router, provider или admin-auth helpers и ограничен тремя файлами в `src/site/`.

## Текущая карта слоев
```text
Сборка / рантайм
  apps/admin, apps/site, vite.config.ts, Dockerfile, nginx/

Оболочки приложений
  src/admin/admin-app.tsx
  src/site/site-app.tsx

Состояние / доступ к данным
  src/shared/live-data-context.tsx
  src/shared/hooks/*
  src/shared/admin-auth.ts
  src/shared/api-client.ts

Интерфейс фич
  src/admin/*
  src/site/site-app.tsx
  src/site/site-home-page.tsx

Презентационный слой / ассеты
  src/styles.css
  src/site/site.css
  src/shared/* UI-примитивы
  public/logo_anton_shell.svg
  public/favicon.png
```

## Сводка по рантайму
| Приложение | Точка входа | Router | Основной контейнер состояния | Текущий статус |
|---|---|---|---|---|
| `admin` | `apps/admin/main.tsx` -> `src/admin/admin-app.tsx` | `BrowserRouter` | `LiveDataProvider` на всех маршрутах кроме `/login` | Активен и используется как operational UI |
| `site` | `apps/site/main.tsx` -> `src/site/site-app.tsx` | отсутствует | отсутствует | Активная сборка ограничена одной статической страницей |

## Ключевые проектные правила в текущей реализации
- Разделение приложений происходит на уровне entrypoint сборки, а не на уровне отдельных репозиториев.
- `admin` и `site` обслуживаются как два разных nginx-контейнера, но оба проксируют `/api/` на один и тот же backend.
- Глобальный orchestrator данных существует только в `admin`.
- Showcase-маршруты продукта и каталога сейчас принадлежат `admin`, а не `site`.
- `site` изолирован от admin не только по маршрутам, но и по стилям: он не импортирует `src/styles.css`.
- `src/shared` не является строго нейтральным слоем: там находятся auth-helpers, `LiveDataProvider` и браузерные API-обертки, ориентированные на `admin`.

## Индекс документов
| # | Файл | Назначение | Зависит от |
|---|---|---|---|
| 00 | `00-OVERVIEW.md` | Карта домена и порядок чтения | - |
| 01 | `01-project-setup.md` | Vite, Docker, nginx, выбор точки входа, env-переменные | 00 |
| 02 | `02-app-entrypoints-and-routing.md` | Композиция admin и site приложений, маршруты, guards | 01 |
| 03 | `03-shared-types-and-transformers.md` | Слой TypeScript-моделей, helper-функции, формирование полей | 01 |
| 04 | `04-auth-and-session-flow.md` | Вход, refresh, logout, поведение защищенных маршрутов | 02, 03 |
| 05 | `05-data-access-and-live-context.md` | Provider, hooks, polling, паттерны refresh | 03, 04 |
| 06 | `06-admin-shell-and-tab-orchestration.md` | `AdminPage`, диспетчеризация вкладок, overlays, жизненный цикл | 02, 05 |
| 07 | `07-admin-catalog-moderation-and-categories.md` | Рабочие потоки продуктов, dedup и категорий | 05, 06 |
| 08 | `08-admin-sources-pricing-weight-and-settings.md` | Sources, designers, pricing, weight, settings | 05, 06 |
| 09 | `09-public-site-runtime.md` | Минимальный изолированный `site` runtime | 02, 10 |
| 10 | `10-ui-styling-and-static-assets.md` | CSS, icons, skeletons, брендовые ассеты, поведение nginx | 01, 02 |

## Порядок чтения
1. Начните с `01-project-setup.md`, чтобы понять, как выпускаются `frontend-admin` и `frontend-site`.
2. Затем прочитайте `02-app-entrypoints-and-routing.md` и `04-auth-and-session-flow.md`.
3. Перед любым документом по admin-функциональности прочитайте `05-data-access-and-live-context.md`.
4. Для активного admin-рантайма читайте `06`, `07` и `08`.
5. `09` описывает только минимальный отдельный сайт и намеренно короток.
6. `10` фиксирует границы CSS и статических ассетов между двумя приложениями.

## Междоменные зависимости
- Контракт Backend API: endpoints `/api/v1/*`, потребляемые напрямую из TypeScript string literals.
- Контракт auth/session: `/api/v1/auth/login`, `/auth/me`, `/auth/refresh`, `/auth/logout`.
- Контракт showcase/catalog: `/api/v1/catalog/*`, `/api/v1/products/*`, `/api/v1/showcase/*`.
- Зависимость от reverse proxy: оба frontend-контейнера проксируют `/api/` на `backend:8000`.

## Текущие ограничения
- `src/shared` смешивает общие UI-примитивы и admin-ориентированную orchestration-логику.
- `LiveDataProvider` по-прежнему классифицирует все маршруты вне `/control*` как `site`-ветку bootstrap, даже когда эти маршруты принадлежат `admin` showcase.
- API-типы написаны вручную локально; сгенерированного клиента нет.
- Крупные coordinator-файлы по-прежнему остаются в `admin`, особенно `src/admin/admin-page.tsx` и `src/shared/live-data-context.tsx`.
