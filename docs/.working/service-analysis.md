# Архитектурная заметка по service-модулю

## Область охвата
Эта заметка описывает текущий модуль `service` в `wardrobe-parser-platform/service`. Она основана только на проверенных коде и конфигурации.

## Назначение и границы модуля

| Аспект | Текущее поведение |
|---|---|
| Основная роль | Запускает parser/sync workflows для внешних storefront-источников и предоставляет API управления sync/status через FastAPI. |
| Чем владеет | Файлом source registry config, source-specific parsing config, in-memory sync jobs/events, source run reports. |
| Чем не владеет | Персистентностью основного product catalog, admin-facing source profiles, authoring weight rules, frontend routing. |
| Внешние выходы | Payload `SourceRunReport`, in-memory job events, включая `product_batch`, и изменения source config, сохраняемые обратно в `config/sources.json`. |
| Внешние зависимости | Public storefronts, backend weight-rules contract endpoint, локальный Node/Chromium browser runner для browser-based strategies. |

Модуль представляет собой отдельный FastAPI-сервис с маршрутами `/health` и `/api/v1/sync/*`. Это не общий shared API layer; его API-поверхность узко сфокусирована на списке источников, patch-обновлении source config, single-source runs, sync jobs, probe jobs, статусах job, events job и отмене.

## Структура верхнего уровня

| Область | Файлы | Роль |
|---|---|---|
| Bootstrap приложения | `app/main.py`, `app/core/app_factory.py`, `app/core/config.py` | FastAPI app, CORS, settings. |
| HTTP API | `app/api/v1/sync.py` | Sync routes и оформление request/response. |
| Service layer | `app/services/source_run_service.py`, `app/services/sync_orchestrator_service.py` | Выполнение по одному источнику и multi-source in-memory orchestration. |
| Registry/factory | `app/services/source_run_service_factory.py`, `app/adapters/registry.py`, `app/strategies/registry.py` | Ручной wiring adapters и strategies на каждой сборке. |
| Хранилище source config | `app/repositories/source_repository.py`, `config/sources.json` | Файловые source definitions и изменяемые flags/config на уровень источника. |
| Parsing contracts | `app/adapters/contracts.py` | `SourceContext`, `StrategyContext`, `SiteAdapter`, `Strategy`. |
| Логика по конкретным источникам | `app/adapters/*.py`, `app/strategies/*.py` | Source normalization/validation и extraction logic конкретных стратегий. |
| Browser runtime | `browser_runner/*` | Node/Chromium runner, используемый browser-based strategies. |

## FastAPI и sync-flow
### Поток запроса
`Router -> SourceRunServiceFactory -> SourceRunService or SyncOrchestratorService`

### Группы маршрутов

| Группа маршрутов | Назначение |
|---|---|
| `GET /api/v1/sync/sources` | Возвращает service-side записи реестра источников из `sources.json`. |
| `PATCH /api/v1/sync/sources/{source_key}` | Изменяет `enabled`, `sync_enabled` и выбранные валютные настройки в `sources.json`. |
| `POST /api/v1/sync/sources/{source_key}/run` | Запускает один источник синхронно и возвращает `SourceRunReport`. |
| `POST /api/v1/sync/jobs` | Создает multi-source async sync-job через `sync_orchestrator`. |
| `POST /api/v1/sync/probe/jobs` | Создает probe-job для одного product URL через `probe_orchestrator`. |
| `GET /api/v1/sync/jobs/*`, `GET /api/v1/sync/probe/jobs/*` | Возвращает latest/job status и event streams. |
| `POST /api/v1/sync/jobs/{job_id}/cancel` | Помечает job как cancelled в состоянии orchestrator. |

### Flow запуска по одному источнику
1. Загрузить `SourceRecord` из `SourceRepository`.
2. Разрешить adapter по `adapter_key`.
3. Провалидировать source config через `ConfigValidationService`.
4. Построить `SourceContext` и начальный `SourceRunReport`.
5. Обнаружить URL видимого каталога через adapter, если источник не в `manual` mode и если caller не форсирует candidate URLs.
6. Получить weight rules из backend через `WeightRulesClient`.
7. Выполнить стратегии из `strategy_sequence` с retry limits из source config.
8. Для каждого strategy item: adapter normalization -> cleanup description -> weight enrichment -> dedup/quarantine -> validation.
9. Вычислить coverage относительно видимого каталога и завершить раньше, если coverage достигает `1.0`.
10. Вернуть итоговый `SourceRunReport` с valid products, unavailable products, attempts, diagnostics и counters.

### Flow multi-source orchestration
`SyncOrchestratorService` хранит runtime jobs в памяти и выполняет их через `ThreadPoolExecutor`. Для каждого источника он:
1. Публикует lifecycle events (`job_started`, `source_started`, `source_progress`, `product_batch`, `source_finished`, terminal job event).
2. Подписывается на progress callbacks `RunLogger`, приходящие от выполнения strategy.
3. Вызывает переданную `runner` lambda, которая делегирует в `SourceRunService.run(...)`.
4. Нормализует valid и часть unavailable products в элементы `product_batch`.
5. Выполняет `requeue` неудачных источников один раз (`max_source_requeues = 1`).
6. Помечает финальный статус job как `completed`, `failed` или `cancelled`.

Orchestrator не сохраняет jobs и events вне памяти процесса.

## Adapters, strategies и browser runner

### Роль adapter
Adapters определяют source-specific boundaries:
- допустимые стратегии для источника
- discovery видимого каталога
- normalization в unified product shape
- причины validation, такие как `missing_price`, `missing_currency`, `missing_weight`, `missing_variants`

Большинство Shopify-like adapters — это почти клоны с source-specific `adapter_key` и общими normalization patterns. Non-Shopify sources, такие как GOAT и Vinted, имеют отдельные adapters с более узкими наборами допустимых strategies.

### Роль strategy
Strategies реализуют механизмы извлечения:

| Семейство стратегий | Роль |
|---|---|
| `shopify_json` | Читает Shopify JSON endpoints, выполняет пагинацию, применяет валютную политику, при необходимости делает JS enrichment. |
| `shopify_js` | Обнаруживает product URLs и конкурентно загружает `.js` payload для каждого продукта. |
| `shopify_browser_extension` | Запускает Node/Chromium runner и разбирает JSON output из browser automation. |
| `vinted_jsonld`, `grailed_algolia_jsonld`, `intl_protocol_index_cafe24`, `store_backlash_colorme`, `goat_browser_extension` | Site/platform-specific extraction paths. |

### Роль browser runner
`browser_runner` — это отдельный Node module, поставляемый внутри service image. Он:
- запускает Chromium, при необходимости под `Xvfb`
- подключается к browser extension bridge по WebSocket
- разрешает site scenario из `src/scenarios/registry.mjs`
- экспортирует product previews в JSON
- записывает machine-readable payload, который потребляет `ShopifyBrowserExtensionStrategy`

Этот runtime обязателен для источников, у которых задан `browser_extension.script_path`, и также оборачивается `goat_browser_extension`.

## Модель config и владение конфигурацией

| Источник config | Владелец в коде | Примечания |
|---|---|---|
| Environment settings | `app/core/config.py` | `service_name`, `cors_allowed_origins`, `backend_base_url`. |
| Source registry | `config/sources.json` через `SourceRepository` | Канонический список service-side источников и parser config на уровень источника. |
| Runtime source toggles | `PATCH /sync/sources/{source_key}` -> `SourceRepository.patch_flags()` | Меняет `sources.json` in place. |
| Strategy policies | Вложены в `config` каждого источника | Обязательные ключи зависят от семейства strategy. |

Наблюдаемое владение:
- Service владеет parser execution config на уровень источника, включая порядок стратегий, retry limits, timeouts, валютное поведение, browser-runner config и режим (`auto`/`manual`).
- Backend владеет authoring weight rules и предоставляет public parser-contract endpoint, который потребляет service.
- Backend также владеет более богатым source profile data, хранящимся в БД; он объединяет эти данные с service-side source config в своем `/sources` API.

## Владение данными, взаимодействия с БД, отчеты и связь с backend

| Тема | Текущее поведение |
|---|---|
| Персистентность продуктов | В этом модуле не реализована. Нет service-side repository/model layer, который писал бы parser products в БД. |
| Использование БД в коде | Docker env `service` включает `DATABASE_URL`, а зависимости включают SQLAlchemy/Alembic, но проверенный код service-модуля не определяет DB sessions/models и не использует `DATABASE_URL`. |
| Персистентность source config | Только файловый JSON (`config/sources.json`). |
| Персистентность job | Только in-memory внутри `SyncOrchestratorService`. |
| Output запуска | `SourceRunReport` плюс события `product_batch` с нормализованными item и lineage variants. |
| Связь с backend | Service получает weight rules из backend по `GET /api/v1/public/parser-contract/weight-rules`. Backend, в свою очередь, вызывает маршруты service `/api/v1/sync/*`, чтобы стартовать jobs, читать events и patch-ить source config. |

Текущий service производит результаты parsing и transient sync-event batches; модулем, который, по-видимому, владеет catalog persistence, source profile enrichment и admin-facing aggregation, является backend.

## Runtime-зависимости

| Зависимость | Подтверждение в коде |
|---|---|
| Python 3.12 | `service/Dockerfile` использует base image `python:3.12-slim`. |
| FastAPI + uvicorn | `requirements.txt`, `app/main.py`. |
| Node.js + npm | Устанавливаются в `service/Dockerfile`; browser runner имеет собственный `package.json`. |
| Chromium | Устанавливается в `service/Dockerfile`; обязателен для browser-extension strategy. |
| Xvfb | Устанавливается в `service/Dockerfile`; нужен browser runner при `show_ui=false`. |
| `ws`, `fast-xml-parser` | Зависимости browser runner. |
| Публичный сетевой доступ | Нужен HTTP-стратегиям storefront и browser runner. |
| Доступность backend по HTTP | Нужна для live-запросов weight rules; при сбое происходит деградация до пустых rules. |

## Взаимодействие с другими модулями

| Взаимодействие | Направление | Текущий контракт |
|---|---|---|
| Backend -> Service | HTTP | Backend строит URL из `SERVICE_BASE_URL` и вызывает `/api/v1/sync/sources`, `/jobs` и связанные endpoints. |
| Service -> Backend | HTTP | Service вызывает backend public parser contract для weight rules через `BACKEND_BASE_URL`. |
| Frontend -> Backend | HTTP | Проверенный frontend-код опрашивает `${API_BASE}/jobs/latest` и `${API_BASE}/sources/...`; в backend есть соответствующие sync/source routes, и он, по-видимому, proxy-ит или агрегирует service data. |
| Frontend -> Service | Прямое использование не выявлено в проверенном frontend-коде | Прямых frontend-вызовов к `/api/v1/sync/*` в проверенных frontend files не найдено. |

## Фактические структурные наблюдения

| Наблюдение | Подтверждение |
|---|---|
| Ключевые файлы крупные и multi-responsibility | `sync.py` — 529 строк, `source_run_service.py` — 456, `sync_orchestrator_service.py` — 610, `shopify_json.py` — 686. |
| Wiring factory ручной и централизованный | `SourceRunServiceFactory.build()` явно регистрирует каждый adapter и каждую strategy. |
| Source registry — это изменяемый общий JSON | `SourceRepository.patch_flags()` переписывает весь файл `sources.json`. |
| Runtime job state process-local | `SyncOrchestratorService` хранит `_jobs`, `_active_job_id`, `_latest_job_id` только в памяти. |
| Service API и backend API связаны зеркальными sync-concepts | Backend строит service URL `/api/v1/sync` и объединяет service source config с backend DB state источников. |
| Поверхность adapters широкая, но повторяющаяся | Многие adapter files имеют ~116 строк и сходную структуру. |
| Browser fallback встроен в service image | `service/Dockerfile` устанавливает Node/npm/Chromium/Xvfb и копирует `browser_runner` в тот же контейнер. |
| Config validation управляется runtime на уровень источника | Отсутствующий или невалидный nested source config вызывает `ConfigError` во время выполнения, а не через compile-time schema. |

## Короткое резюме
Текущий модуль `service` — это execution-oriented parser/sync service. Его durable ownership ограничивается файловым source registry и parser configuration; его runtime ownership — это in-memory orchestration jobs/events и per-run reports. Он зависит от backend в части weight-rule configuration и от backend-facing consumers, которые превращают emitted `product_batch` events в persistent catalog state.
