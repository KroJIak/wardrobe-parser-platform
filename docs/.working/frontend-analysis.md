# Анализ frontend-модуля

## Назначение модуля

Подмодуль `frontend` сейчас содержит две точки входа web app внутри одного Vite-проекта:

| App | Entrypoint | Текущая роль в runtime |
|---|---|---|
| `admin` | `apps/admin/main.tsx` -> `src/admin/admin-app.tsx` | Основное активное приложение: аутентифицированная admin panel с routing, data provider и tooling для sync/catalog/settings |
| `site` | `apps/site/main.tsx` -> `src/site/site-app.tsx` | Текущий активный runtime — placeholder-страница, которая рендерит только `"be monki"` |

В репозитории по-прежнему существует более крупная реализация `src/site/*` (`catalog-page`, `product-page`, `layout`, helpers`), но `src/site/site-app.tsx` этот код не монтирует. Он только задает `document.title` и рендерит placeholder shell.

## Структура сборки и runtime

| Аспект | Текущая реализация |
|---|---|
| Bundler | Vite 5 с `@vitejs/plugin-react` и `@tailwindcss/vite` |
| Выбор приложения | `vite.config.ts` выбирает `apps/site` в режиме `site`, иначе `apps/admin` |
| Алиасы | `@` -> `src`, `@admin` -> `src/admin`, `@site` -> `src/site`, `@shared` -> `src/shared` |
| Dev-команды | `npm run dev:admin`, `npm run dev:site` |
| Build-команды | `npm run build:admin`, `npm run build:site` |
| Output | единый каталог `dist/` на сборку |
| Переключатель Docker build | `FRONTEND_APP=admin|site` в `frontend/Dockerfile` |
| Runtime server | `nginx:alpine`, раздающий статические файлы на порту `80` |
| API routing в Docker | nginx проксирует `/api/` в `http://backend:8000` |
| API routing в локальном Vite dev | `/api` проксируется в `VITE_LOCAL_API_URL` или fallback `http://localhost:10510` |

Оба приложения разделяют `src/styles.css`. Исходное дерево — это один проект с двумя build roots, а runtime-доступ к API в dev и Docker одинаково same-origin.

## Раскладка исходников

| Путь | Роль |
|---|---|
| `apps/admin/` | Admin HTML shell и `main.tsx` |
| `apps/site/` | Site HTML shell и `main.tsx` |
| `src/admin/` | Admin app, tabs, screens, hooks, auth-facing UI |
| `src/site/` | Site/catalog/product UI и helpers |
| `src/shared/` | Общий context, hooks, auth wrapper, API helpers, toasts, icons, image helpers, common UI |

Приблизительный объем по числу строк TS/TSX в текущих файлах:

| Область | Примерный TS/TSX LOC | Наибольшие файлы |
|---|---:|---|
| `src/admin` | `11362` | `admin-sources-tab.tsx` `884`, `use-admin-product-create-mock.ts` `789`, `admin-page.tsx` `785`, `admin-settings-accounts-section.tsx` `689` |
| `src/site` | `2125` | `catalog-page.tsx` `778`, `product-page.tsx` `770`, `catalog-helpers.ts` `359` |
| `src/shared` | `3871` | `live-data-context.tsx` `701`, `live-data-types.ts` `646`, `use-live-data-source-settings-actions.ts` `329`, `use-live-data-admin-reference.ts` `260` |

## Текущая структура приложений

### Admin

- `AdminApp` монтирует `BrowserRouter` и маршруты `/login`, `/control/:tab`, а также redirect с `/` и `/control`.
- `LiveDataProvider` оборачивает только non-login routes.
- `AdminPage` — orchestration-component, который получает большую часть provider state/actions и распределяет их по tab-components.
- Tabs определены в `admin-constants.ts`: `products`, `dedup`, `categories`, `designers`, `sources`, `pricing`, `weight`, `settings`.

### Site

- `SiteApp` сейчас не имеет router, `LiveDataProvider` и не использует `src/site/layout.tsx`, `home-page.tsx`, `category-page.tsx`, `catalog-page.tsx` или `product-page.tsx`.
- Dormant site implementation все еще присутствует в исходниках и импортирует shared/admin-oriented utilities.

## State, data flow и паттерны API-клиента

### Главный контейнер state

`src/shared/live-data-context.tsx` — это центральный контейнер состояния для non-login admin runtime. Он владеет широким cross-feature state:

- products и pagination
- sources
- latest sync job
- admin categories и derived public categories
- dedup candidates и decisions
- weight rules и missing-weight products
- pricing settings
- admin UI settings
- flags ошибок и загрузки

Provider композиционно использует несколько feature hooks:

- `useLiveDataAdminCore`
- `useLiveDataAdminReference`
- `useLiveDataCategoryDedupActions`
- `useLiveDataProductActions`
- `useLiveDataSourceSettingsActions`
- `useLiveDataBootstrap`
- `useLiveJobPolling`

### Паттерны fetch

| Паттерн | Текущее использование |
|---|---|
| `authFetch()` | Базовая authenticated fetch-wrapper; всегда посылает `credentials: "include"` и один раз повторяет запрос после `401` через `/auth/refresh` |
| `apiJson()` / `apiNoContent()` | Тонкие JSON helpers поверх `authFetch()`, используемые многими shared hooks |
| Raw `fetch()` | По-прежнему используется напрямую в ряде мест, включая admin login и текущие site/catalog requests |

### Стратегия обновления данных

- Bootstrap provider чувствителен к типу маршрута: `useLiveDataBootstrap` выводит `"admin"` против `"site"` из pathname и предварительно загружает разные наборы данных.
- Polling sync зависит от pathname и включен только для `/control*`.
- Некоторые mutation сразу patch-ят local state; другие запускают грубые refresh, такие как `refreshProductsOnly`, `refreshSourcesOnly`, `refreshWeightOnly`, `refreshCategoriesOnly` или полный `refresh()`.

## Обработка auth и session

| Аспект | Текущее поведение |
|---|---|
| База auth | Захардкоженный `API_BASE = "/api/v1"` |
| Login | `POST /api/v1/auth/login` через raw `fetch()` в `AdminLoginRoute` |
| Проверка session | `GET /api/v1/auth/me` |
| Refresh | `POST /api/v1/auth/refresh` |
| Logout | `POST /api/v1/auth/logout` |
| Transport session | Основан на cookie/session; каждый authenticated request использует `credentials: "include"` |
| Обработка истечения | `authFetch()` ставит флаг session-expired в `sessionStorage` и отправляет `admin-auth-expired` |

`useShowcaseEditPermission()` тоже вызывает `/auth/me` и кэширует boolean permission result в module scope. Этот hook импортируется и site-components, и shared/admin-adjacent UI.

## UI, страницы и зависимости

### Структура admin UI

- `AdminPage` — крупный coordinator-component, который связывает provider state, tab-local hooks, toasts, sync controls, overlays, product creation flow, pricing flow, dedup flow, category flow и settings transfer flow.
- Основная сегментация UI после `/control/:tab` строится по вкладкам, а не по маршрутам.
- `admin-tab-content.tsx` переключает активный tab-component через явные conditionals.

### Site UI, присутствующий в исходниках

- `catalog-page.tsx` и `product-page.tsx` реализуют более богатое showcase/catalog behavior, но не монтируются текущим `SiteApp`.
- Эти компоненты ожидают `useLiveData()` и permissions из `useShowcaseEditPermission()`.
- `product-page.tsx` импортирует pricing/view helpers из `src/admin` (`admin-pricing-view-model`, `admin-formatters`).
- `layout.tsx` содержит admin-aware CTA и logout behavior.

### Заметные runtime-зависимости, реально импортируемые кодом

- `react`, `react-dom`
- `react-router-dom`
- `lucide-react`
- `katex`

## Связность между admin, site, shared и backend-contracts

### Admin <-> Shared

- `shared` не является нейтральным слоем утилит; в нем есть admin auth, admin-oriented provider state и множество admin API actions.
- `AdminApp` зависит от `shared/live-data-context` и `shared/admin-auth` почти для всего data/session behavior.

### Site <-> Shared/Admin

- Существующие site-components зависят от `useLiveData()` из `shared/live-data-context`, который сейчас спроектирован вокруг admin datasets и authenticated fetch.
- `product-page.tsx` напрямую импортирует admin pricing helpers из `src/admin`.
- `SiteLayout` импортирует `logoutAdminSession()` и в зависимости от контекста ведет пользователя к `/control/products`.

### Frontend <-> Backend

- Пути API — это строковые литералы, разбросанные по provider/hooks/components под `/api/v1/...`.
- Формы типов — локально написанные TypeScript-типы в `live-data-types.ts` и payload-типы внутри компонентов.
- Генерируемый API client или общий источник schema в этом модуле не виден.
- Текущий код предполагает конкретные backend resources, такие как:
  - `/auth/*`
  - `/products*`
  - `/sources*`
  - `/jobs*`
  - `/categories*`
  - `/dedup*`
  - `/settings*`
  - `/showcase*`
  - `/catalog/*`
  - `/admin/*`

## Фактические проблемные точки, видимые по структуре

- Разделение приложений существует на уровне build-entry, но изоляция исходников частичная: `site`, `admin` и `shared` все еще напрямую ссылаются друг на друга.
- `shared/live-data-context.tsx` — это крупный cross-feature state hub, а не узкий shared layer.
- Несколько файлов являются большими orchestration-components или hooks (`700-880` строк), особенно в admin.
- Знание API-контракта распределено по множеству строковых endpoint и локальных payload-types, а не сосредоточено в одном типизированном contract layer.
- Fetch behavior смешан: часть кода использует централизованные helpers, часть — raw `fetch()`.
- В исходниках присутствует dormant site implementation, не являющаяся частью текущего runtime `SiteApp`.
- Текущий site-related source частично ориентирован на admin, а не только на public site, через permission checks, logout wiring и импорты из admin files.
