# Проектирование фронтенда

## Охват
- Охватывает: текущий рантайм фронтенда, структуру исходников, схему сборки и деплоя, композицию приложений, общее состояние, auth-поток, архитектуру админских вкладок, рантайм публичного сайта, стили и ассеты.
- Не охватывает: бизнес-правила backend, внутреннее устройство parser-service, владение схемой базы данных.
- Зависит от: дерева исходников `frontend/`, `docs/.working/frontend-analysis.md`, `docs/.working/step2.2-domain-internals.md`.

## Назначение
Сабмодуль `frontend` представляет собой один проект Vite, который выпускает два отдельных браузерных приложения:
- `admin`: аутентифицированную админ-панель для модерации каталога, управления sync, ценообразования, weight rules, настроек и учетных записей.
- `site`: сборку публичного сайта. В текущем рантайме она рендерит только страницу-заглушку с текстом `be monki`.

Обе сборки используют один репозиторий исходников и одну глобальную таблицу стилей, однако изоляция кода между ними неполная. `src/shared` содержит не только нейтральные утилиты, но и вспомогательные функции админской сессии, основной `LiveDataProvider` и API-обертки. Часть спящего site-слоя по-прежнему зависит от admin-ориентированных helper-функций.

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
  src/site/*

Презентационный слой / ассеты
  src/styles.css
  src/shared/* UI-примитивы
  public/logo_anton_shell.svg
  public/favicon.png
```

## Сводка по рантайму
| Приложение | Точка входа | Router | Основной контейнер состояния | Текущий статус |
|---|---|---|---|---|
| `admin` | `apps/admin/main.tsx` -> `src/admin/admin-app.tsx` | `react-router-dom` `BrowserRouter` | `LiveDataProvider` на всех маршрутах кроме login | Активен и используется в production-среде |
| `site` | `apps/site/main.tsx` -> `src/site/site-app.tsx` | отсутствует в активной точке входа | отсутствует в активной точке входа | Активная сборка ограничена заглушкой |

## Ключевые проектные правила в текущей реализации
- Разделение приложений происходит на уровне entrypoint сборки, а не на уровне репозитория.
- Активным рантаймом владеет `admin`. Большая часть аутентифицированного потока данных сформирована вокруг admin-сценариев.
- `LiveDataProvider` является главным узлом orchestration для admin-state и мутаций.
- Auth основан на cookie и централизован вокруг `authFetch()` и silent refresh.
- Исходники публичного сайта существуют не только как заглушка, но этот код не монтируется из `SiteApp`.
- Оформление в основном реализовано через вручную написанный глобальный CSS в `src/styles.css`, хотя плагины Tailwind/Vite установлены.

## Индекс документов
| # | Файл | Назначение | Зависит от |
|---|---|---|---|
| 00 | `00-OVERVIEW.md` | Карта домена и порядок чтения | - |
| 01 | `01-project-setup.md` | Vite, Docker, nginx, выбор точки входа, env-переменные | 00 |
| 02 | `02-app-entrypoints-and-routing.md` | Композиция admin и site приложений, маршрутизация, guards | 01 |
| 03 | `03-shared-types-and-transformers.md` | Слой TypeScript-моделей, helper-функции, формирование полей | 01 |
| 04 | `04-auth-and-session-flow.md` | Вход, refresh, logout, поведение защищенных маршрутов | 02, 03 |
| 05 | `05-data-access-and-live-context.md` | Provider, hooks, polling, паттерны refresh | 03, 04 |
| 06 | `06-admin-shell-and-tab-orchestration.md` | `AdminPage`, диспетчеризация вкладок, overlays, жизненный цикл | 02, 05 |
| 07 | `07-admin-catalog-moderation-and-categories.md` | Рабочие потоки продуктов, dedup и категорий | 05, 06 |
| 08 | `08-admin-sources-pricing-weight-and-settings.md` | Sources, designers, pricing, weight, settings | 05, 06 |
| 09 | `09-public-site-runtime.md` | Сайт-заглушка и спящий код каталога и product-page | 02, 03, 05 |
| 10 | `10-ui-styling-and-static-assets.md` | CSS, icons, skeletons, брендовые ассеты, поведение nginx | 01, 02 |

## Порядок чтения
1. Начните с `01-project-setup.md`, чтобы понять, как выпускаются две сборки.
2. Затем прочитайте `02-app-entrypoints-and-routing.md` и `04-auth-and-session-flow.md`, чтобы понять границы рантайма.
3. Перед любым документом по admin-функциональности прочитайте `05-data-access-and-live-context.md`.
4. Для активного admin-рантайма прочитайте `06`, `07` и `08`.
5. `09` читайте отдельно, потому что дерево исходников публичного сайта активно лишь частично.
6. `10` фиксирует соглашения presentation-layer и обработку статических ассетов.

## Междоменные зависимости
- Контракт Backend API: endpoints `/api/v1/*`, которые потребляются напрямую из TypeScript string literals.
- Контракт auth/session: `/api/v1/auth/login`, `/auth/me`, `/auth/refresh`, `/auth/logout`.
- Контракт публичного catalog/showcase: `/api/v1/catalog/*`, `/api/v1/products/*`, `/api/v1/showcase/*`.
- Зависимость от reverse proxy: в container runtime nginx проксирует `/api/` на `backend:8000`.

## Текущие ограничения
- `src/shared` не является строго общим слоем; он включает admin-ориентированную логику сессии и состояния.
- Некоторые компоненты public-site вызывают admin-ориентированные helpers, такие как `useShowcaseEditPermission()`, `logoutAdminSession()` и утилиты форматирования цен из `src/admin`.
- API-типы написаны вручную локально; внутри frontend-репозитория нет сгенерированного клиента или импорта канонической схемы.
- Несколько coordinator-файлов имеют большой размер и пересекают множество фич, особенно `src/admin/admin-page.tsx` и `src/shared/live-data-context.tsx`.
