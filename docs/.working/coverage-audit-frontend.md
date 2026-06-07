# Аудит покрытия frontend-документацией

## 1. Сводка покрытия

Общее покрытие frontend-документацией высокое, но не полное.

Что уже задокументировано хорошо:
- разделение сборки между `admin` и `site`
- baseline Vite/Docker/nginx
- активный admin routing и flow auth/session
- `LiveDataProvider` как главный hub admin-state
- ответственность admin tabs на уровне features
- активный placeholder site против dormant source tree site
- основные семейства endpoint `frontend -> backend`
- shared styling и модель static assets

Что все еще существенно недодокументировано:
- поведение host-relative navigation после разделения на отдельные deployment `site` и `admin`
- точная семантика bootstrap и polling внутри shared runtime hooks
- preflight-поведение запуска sync в provider
- механика concurrency/caching в dormant catalog
- ограничение nginx по размеру upload

Вердикт:
- документация по направлению верна для текущего frontend
- документация **пока не полностью фиксирует** все важные runtime-поведения, присутствующие в коде
- прежде чем заявлять полное покрытие frontend, нужны правки docs

## 2. Наблюдения по убыванию важности

### High: navigation к admin product задокументирована как “public-style”, но не как нерешенный route на admin SPA host

Документация верно говорит, что navigation к admin product использует путь в стиле public, но не фиксирует фактическое runtime-последствие после split frontend. Admin app переходит на `/product/:id?from=admin` через host-relative URL, тогда как в mounted route table `AdminApp` нет маршрута `/product/:id`. В admin build этот путь проваливается в wildcard-route и редиректит обратно на `/`, а затем в default admin tab.

Это не просто нюанс названия. Это конкретное runtime-поведение в текущей форме split deployment, и его нужно документировать явно.

Code refs:
- `frontend/src/admin/hooks/use-admin-product-navigation.ts:8-20`
- `frontend/src/admin/admin-app.tsx:208-215`

Текущие ссылки на docs:
- `docs/frontend-design/02-app-entrypoints-and-routing.md:115-125`
- `docs/frontend-design/07-admin-catalog-moderation-and-categories.md:54-60`

Docs need changes:
- Yes

Recommended doc delta:
- зафиксировать, что `useAdminProductNavigation()` генерирует путь в site-style
- зафиксировать, что текущий mounted router `admin` этот путь не обслуживает
- зафиксировать, что на admin host текущее поведение проходит через wildcard redirect, а не рендерит product page

### High: `useLiveDataBootstrap()` задокументирован как route-sensitive, но не как route-kind-transition-sensitive

Текущие docs описывают поведение bootstrap для `admin` против `site`, но упускают главное правило gating: bootstrap запускается только когда тип маршрута меняется между `admin` и `site`, потому что hook хранит `lastRouteKindRef` и рано выходит, если тип не изменился.

Это важно, потому что внутренние переключения admin tabs не перезапускают этот bootstrap path. Это поведение делегируется preload табов и другим feature-specific hooks. Без фиксации этого guard docs завышают частоту реального provider bootstrap.

Code refs:
- `frontend/src/shared/hooks/use-live-data-bootstrap.ts:20-33`
- `frontend/src/shared/hooks/use-live-data-bootstrap.ts:34-72`

Текущие ссылки на docs:
- `docs/frontend-design/05-data-access-and-live-context.md:55-68`

Docs need changes:
- Yes

Recommended doc delta:
- явно добавить guard `lastRouteKindRef`
- указать, что bootstrap выполняется на переходах между `admin` и `site`, а не на каждом изменении pathname
- связать это поведение с `useAdminTabPreload()` как механизмом, закрывающим этот пробел при переключении admin tabs

### Medium: docs по polling занижают число случаев, когда после sync-job срабатывают тяжелые refresh

Сейчас docs говорят, что `useLiveJobPolling()` делает refresh после перехода running job в terminal state. Реализация шире:
- refresh также происходит, когда появляется другой terminal `job_id`
- refresh также происходит, когда меняется terminal `completed_at`

Эта более широкая логика важна, потому что не дает пропустить refresh, если текущий экран локально не наблюдал всю running-phase.

Code refs:
- `frontend/src/shared/hooks/use-live-job-polling.ts:35-54`

Текущие ссылки на docs:
- `docs/frontend-design/05-data-access-and-live-context.md:90-100`

Docs need changes:
- Yes

Recommended doc delta:
- заменить упрощенное описание “running -> terminal” на реальную модель с тремя условиями refresh-trigger

### Medium: flow запуска sync недодокументирован на уровне использования endpoint

Provider не просто делает `POST /jobs`. Перед запуском global sync или source-scoped sync он сначала вызывает `GET /jobs/latest` и отказывается стартовать, если последняя job уже находится в `pending` или `in_progress`. Он также обрабатывает backend `409` как отдельный conflict path.

Это реальная orchestration-логика в frontend transport layer, и она должна быть в runtime docs.

Code refs:
- `frontend/src/shared/live-data-context.tsx:315-379`

Текущие ссылки на docs:
- `docs/frontend-design/05-data-access-and-live-context.md:102-123`
- `docs/frontend-design/06-admin-shell-and-tab-orchestration.md:96-109`
- `docs/api/protocols/frontend--backend.md:103-112`

Docs need changes:
- Yes

Recommended doc delta:
- задокументировать preflight `GET /jobs/latest`
- задокументировать guard-путь “already started by another admin”
- задокументировать специальную обработку `409` как часть frontend contract

### Medium: dormant catalog задокументирован функционально, но важное поведение caching и coordination requests отсутствует

`CatalogPage` задокументирован как dormant catalog UI с root hover navigation и cursor pagination. Но из docs пока выпадает operational detail о том, что dormant catalog:
- держит module-scope caches для roots и slug-to-root resolution
- лениво загружает root panels
- отменяет in-flight non-append page requests
- использует monotonic `requestId` guard, чтобы игнорировать stale responses

Эти механизмы напрямую влияют на freshness, обработку гонок и будущую реактивацию.

Code refs:
- `frontend/src/site/catalog-page.tsx:46-49`
- `frontend/src/site/catalog-page.tsx:198-259`
- `frontend/src/site/catalog-page.tsx:291-361`
- `frontend/src/site/catalog-page.tsx:370-446`

Текущие ссылки на docs:
- `docs/frontend-design/09-public-site-runtime.md:33-53`

Docs need changes:
- Yes

Recommended doc delta:
- добавить краткий подраздел о state/cache behavior dormant catalog
- зафиксировать module-scope root caches и механизм abort/request-staleness control

### Low: ограничение nginx по размеру upload отсутствует во frontend и infra docs

Конфиг nginx задает `client_max_body_size 100m`. Поскольку admin UI загружает product images и showcase media через frontend container, это реальное runtime-ограничение, а не случайная деталь реализации.

Code refs:
- `frontend/nginx/nginx.conf:4`

Текущие ссылки на docs:
- `docs/frontend-design/01-project-setup.md:120-127`
- `docs/frontend-design/10-ui-styling-and-static-assets.md:91-98`
- `docs/infra-design/01-local-compose.md:60-85`
- `docs/infra-design/02-hosted-dokploy-and-networking.md:41-50`

Docs need changes:
- Yes

Recommended doc delta:
- задокументировать лимит request body в 100 MB во frontend runtime docs
- упомянуть его и в infra docs, где описано upload behavior

### Low: cache-семантика `useShowcaseEditPermission()` описана лишь частично

Docs говорят, что hook кэширует boolean result в module scope. Это верно, но реализация также кэширует negative result при fetch-failure или unauthorized access. На практике это означает, что временный сбой может заставить hook оставаться `false` до перезагрузки страницы.

Это менее важно, чем findings выше, но это все равно runtime-поведение, реально присутствующее в коде.

Code refs:
- `frontend/src/shared/use-showcase-edit-permission.ts:12-43`
- `frontend/src/shared/use-showcase-edit-permission.ts:45-61`

Текущие ссылки на docs:
- `docs/frontend-design/04-auth-and-session-flow.md:107-117`
- `docs/frontend-design/09-public-site-runtime.md:79-85`

Docs need changes:
- Yes

Recommended doc delta:
- уточнить, что cache сохраняет и положительные, и отрицательные результаты на время жизни текущей страницы

## 3. Точные замечания по покрытию по областям

### Форма entry/build/deploy

Качество покрытия: strong

Хорошо покрыто:
- разделение entry между `apps/admin` и `apps/site`
- `React.StrictMode`
- выбор режима Vite
- выбор Docker build через `FRONTEND_APP`
- same-origin proxy для `/api`
- модель общего output `dist/`

Небольшая недостающая деталь:
- `nginx client_max_body_size 100m`

Primary refs:
- code: `frontend/apps/admin/main.tsx:1-11`, `frontend/apps/site/main.tsx:1-11`, `frontend/vite.config.ts:6-44`, `frontend/Dockerfile:1-38`, `frontend/nginx/nginx.conf:1-25`
- docs: `docs/frontend-design/01-project-setup.md`, `docs/frontend-design/02-app-entrypoints-and-routing.md`, `docs/infra-design/01-local-compose.md`, `docs/infra-design/02-hosted-dokploy-and-networking.md`

### Flow auth/session

Качество покрытия: strong

Хорошо покрыто:
- login screen через raw `fetch()`
- refresh-поведение `authFetch()`
- flow `/login?reason=expired`
- logout behavior
- прямые проверки `/auth/me` в feature-code

Остающийся пробел:
- negative-result caching semantics у `useShowcaseEditPermission()`

Primary refs:
- code: `frontend/src/admin/admin-app.tsx:77-152`, `frontend/src/shared/admin-auth.ts:1-80`, `frontend/src/shared/use-showcase-edit-permission.ts:1-62`
- docs: `docs/frontend-design/04-auth-and-session-flow.md`, `docs/api/auth.md`

### Shared state и orchestration provider

Качество покрытия: medium-high

Хорошо покрыто:
- `LiveDataProvider` как главный hub admin-state
- семейства данных provider
- lazy loaders и focused refreshes
- размер product pagination `100`

Существенные пробелы:
- bootstrap выполняется только при смене route kind
- логика refresh в polling шире, чем сейчас задокументировано
- sync start preflight недодокументирован

Primary refs:
- code: `frontend/src/shared/live-data-context.tsx:35-245`, `frontend/src/shared/live-data-context.tsx:315-379`, `frontend/src/shared/hooks/use-live-data-bootstrap.ts:13-72`, `frontend/src/shared/hooks/use-live-job-polling.ts:17-64`
- docs: `docs/frontend-design/05-data-access-and-live-context.md`, `docs/frontend-design/06-admin-shell-and-tab-orchestration.md`

### Admin shell и routes

Качество покрытия: medium-high

Хорошо покрыто:
- route table
- граница login/provider
- sync заголовка route title
- transition indicator
- структура shell, управляемая табами

Существенный пробел:
- assumptions host-relative navigation после split `site/admin` описаны не полностью

Primary refs:
- code: `frontend/src/admin/admin-app.tsx:154-241`, `frontend/src/admin/admin-topbar.tsx:8-16`, `frontend/src/admin/hooks/use-admin-product-navigation.ts:5-24`
- docs: `docs/frontend-design/02-app-entrypoints-and-routing.md`, `docs/frontend-design/06-admin-shell-and-tab-orchestration.md`, `docs/frontend-design/07-admin-catalog-moderation-and-categories.md`

### Dormant site implementation

Качество покрытия: medium

Хорошо покрыто:
- активный placeholder `SiteApp`
- inventory dormant pages
- связность с admin/shared
- семейства public endpoint

Существенный пробел:
- root caching, request abort, stale-response guard и lazy root-panel loading не описаны

Primary refs:
- code: `frontend/src/site/site-app.tsx:1-12`, `frontend/src/site/layout.tsx:1-37`, `frontend/src/site/catalog-page.tsx:46-49`, `frontend/src/site/catalog-page.tsx:198-259`, `frontend/src/site/catalog-page.tsx:291-361`, `frontend/src/site/product-page.tsx:78-229`
- docs: `docs/frontend-design/09-public-site-runtime.md`, `docs/api/protocols/frontend--backend.md`

### Styling и assets

Качество покрытия: strong

Хорошо покрыто:
- владение global stylesheet
- shared brand assets
- слои KaTeX и icons
- визуальная обработка placeholder-site
- раздача static assets через nginx

Небольшая недостающая деталь:
- operational upload body-size cap уместен и здесь

Primary refs:
- code: `frontend/src/styles.css`, `frontend/src/shared/site-header.tsx:17-58`, `frontend/nginx/nginx.conf:1-25`
- docs: `docs/frontend-design/10-ui-styling-and-static-assets.md`

## 4. Нужны ли изменения в docs

Да.

Рекомендуемый минимальный набор обновлений перед тем, как считать frontend coverage complete:
1. Задокументировать, что navigation по admin product-card ведет в site-style route, который `AdminApp` не монтирует.
2. Задокументировать, что `useLiveDataBootstrap()` выполняется только когда route kind меняется между `admin` и `site`.
3. Задокументировать полную семантику refresh-trigger в `useLiveJobPolling()`.
4. Задокументировать preflight-поведение запуска sync вокруг `GET /jobs/latest` и обработки `409`.
5. Задокументировать caching и request-staleness control dormant catalog.
6. Задокументировать `nginx client_max_body_size 100m`.
7. Уточнить negative-result caching в `useShowcaseEditPermission()`.

## Остаточные области с низкой уверенностью

Эти области не выглядят очевидно пропущенными, но уверенность по ним ниже, потому что они большие и описаны в основном на feature-level, а не file-by-file:
- точная внутренняя choreography state внутри `src/admin/admin-page.tsx`
- покрытие fine-grained CSS selectors в `src/styles.css`
- edge-case behavior внутри больших admin feature-files, таких как `admin-sources-tab.tsx` и `use-admin-product-create-mock.ts`

Текущее заключение:
- frontend docs уже достаточно сильны для архитектурной работы
- frontend docs **пока недостаточно исчерпывающи**, чтобы утверждать полное соответствие кода и docs
