# Проектирование фронтенда: доступ к данным и live-context

## Охват
- Охватывает: `LiveDataProvider`, общие API-helpers, composed hooks, семантику refresh, polling, route-sensitive bootstrap, стратегию мутаций.
- Не охватывает: layout отдельных admin-экранов или минимальный `site`.
- Зависит от: `src/shared/live-data-context.tsx`, `src/shared/api-client.ts`, `src/shared/hooks/*`.

## Модель доступа к данным
Активное `admin`-приложение использует context-centered модель состояния:
- один верхнеуровневый `LiveDataProvider`
- множество feature-specific hooks, собранных в этот provider
- consumers читают state и actions через `useLiveData()`

Это главный центр данных рантайма для `admin` вне login.

## Слои fetch-доступа
Frontend сейчас использует три стиля доступа к API.

| Слой | Файлы | Назначение |
|---|---|---|
| `authFetch()` | `src/shared/admin-auth.ts` | аутентифицированный transport с silent refresh |
| `apiJson()` / `apiNoContent()` | `src/shared/api-client.ts` | типизированные helpers для JSON и no-content ответов |
| raw `fetch()` | login и несколько feature-файлов | прямые вызовы там, где helpers не используются |

Предпочтительный общий путь проходит через `apiJson()` или `apiNoContent()` поверх `authFetch()`.

## Поверхность состояния provider
`LiveDataProvider` владеет следующими крупными группами состояния:
- products, totals пагинации и flags для `load more`
- sources
- latest sync job
- производные публичные категории
- полное admin-дерево категорий
- dedup candidates и dedup decisions
- pricing settings
- admin UI settings
- weight rules и продукты без веса
- состояние loading/error для bootstrap и инкрементальных загрузок

Он экспортирует и данные, и мутации через `LiveDataContextValue`.

## Композиция hooks
`LiveDataProvider` строится из нескольких hooks:

| Hook | Ответственность |
|---|---|
| `useLiveDataAdminCore` | загружает sources и latest job |
| `useLiveDataAdminReference` | загружает categories, dedup, pricing, admin UI и reference-наборы weight |
| `useLiveDataCategoryDedupActions` | CRUD категорий, ручные category-product links, dedup-операции |
| `useLiveDataProductActions` | preview/probe продуктов, ручное создание/редактирование, image/status/starred categories |
| `useLiveDataSourceSettingsActions` | source flags, pricing settings, showcase settings, import/export/reset, suppliers, weight rules |
| `useLiveDataBootstrap` | route-sensitive начальный bootstrap |
| `useLiveJobPolling` | polling latest job и запуск terminal refresh |

## Поведение bootstrap
`useLiveDataBootstrap()` выводит тип маршрута из `pathname`:
- `/control*` -> `admin`
- все остальное -> `site`

Hook хранит `lastRouteKindRef` и запускает ветку bootstrap только тогда, когда меняется тип маршрута:
- `admin` -> `site`
- `site` -> `admin`

Это означает:
- переключения admin-вкладок сами по себе не вызывают bootstrap повторно
- showcase-маршруты `admin` (`/`, `/catalog`, `/category/:slug`, `/product/:id`) попадают в ветку `site`, хотя работают внутри `admin` deployment

Поведение:
- на `admin`-маршрутах:
  - всегда загружает latest job
  - при необходимости заранее загружает sources для `products`, `sources` и `pricing`
- на маршрутах, классифицированных как `site`:
  - если маршрут совпадает с `/product/:id`, пропускает bootstrap sources
  - иначе загружает только sources

Это реальный текущий код, а не целевая идеальная модель.

## Основные операции refresh
Provider экспортирует несколько форм refresh вместо одного глобального примитива invalidation:
- `refresh()` для грубого bootstrap-refresh
- `refreshSourcesOnly()`
- `refreshProductsOnly()`
- `refreshCategoriesOnly()`
- `refreshDedupOnly()`
- `refreshDedupDecisionsOnly()`
- `refreshPricingOnly()`
- `refreshAdminUiOnly()`
- `refreshWeightOnly()`

Также экспортируются ленивые методы вида `ensure loaded`:
- `ensurePricingLoaded()`
- `ensureAdminUiLoaded()`
- `ensureWeightLoaded()`
- `ensureDedupLoaded()`
- `ensureDedupDecisionsLoaded()`
- `ensureCategoriesLoaded()`

## Модель polling
`useLiveJobPolling()` опрашивает `GET /jobs/latest` с интервалом:
- `1500ms`, пока latest job имеет статус `pending` или `in_progress`
- `7000ms` во всех остальных случаях

Hook запускает focused refresh при любом из следующих terminal-условий:
- предыдущий статус job был running, а следующий статус стал terminal
- появляется другой terminal `job_id`
- меняется terminal `completed_at`

Когда одно из этих условий выполняется, hook вызывает focused refresh:
- `/control/sources` -> refresh только sources
- `/control/products` -> refresh только products
- любой другой `/control*` route -> refresh admin core

Polling включен только тогда, когда маршрут начинается с `/control`.

## Стратегия мутаций
Обработка мутаций следует трем паттернам.

### 1. Патч локального состояния из ответа
Примеры:
- правки source enable/sync/visibility/currency
- patch pricing settings
- patch admin UI settings
- patch product overrides

### 2. Мутация с последующим refresh целевого среза
Примеры:
- CRUD weight-rule -> refresh weight
- изменения keywords категорий -> refresh categories
- CRUD pricing suppliers -> refresh pricing и sources

### 3. Мутация с последующим грубым refresh
Примеры:
- import/reset настроек
- start/cancel sync
- некоторые сценарии ручной работы с продуктами

## Предварительная проверка перед запуском sync
Запуск sync не является слепым `POST /jobs`.

Текущее поведение provider перед стартом sync:
1. делает `GET /jobs/latest`
2. отказывается запускать sync локально, если latest job уже находится в `pending` или `in_progress`
3. пытается выполнить `POST /jobs`
4. интерпретирует backend `409` как отдельный конфликтный сценарий

## Семантика загрузки продуктов
Продукты загружаются с явной пагинацией:
- размер страницы `100`
- скрытые элементы `unavailable` отфильтровываются из provider-списков
- `loadMoreProducts()` добавляет только уникальные продукты по `id`
- `getProductById()` сначала проверяет provider-cache, а затем при необходимости запрашивает `/products/:id`
- `ensureAllProductsLoaded()` может в цикле пройти весь список пагинации

## Обработка ошибок
- `apiJson()` выбрасывает `ApiError` с распарсенным backend `detail`, когда это возможно
- bootstrap provider перехватывает ошибки и хранит одну строку `error`
- многие feature-hooks возвращают результат действия в виде `{ ok, message }`, а не выбрасывают исключение
- некоторые polling- и permission-проверки намеренно завершаются тихо и повторяются позже

## Текущий архитектурный характер
`LiveDataProvider` не является узким shared store. Это широкий слой orchestration, который смешивает:
- transport concerns
- bootstrap datasets
- политику refresh
- dispatch действий на уровне фич
- часть локальной projection-логики

Это делает его центральной точкой интеграции для активного `admin`-runtime.
