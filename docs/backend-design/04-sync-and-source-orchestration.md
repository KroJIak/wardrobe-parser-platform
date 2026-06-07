# Архитектура Backend: Sync и Оркестрация Источников

## Область
- Покрывает: агрегацию backend поверх parser-service, merge source registry, lifecycle sync job, apply pipeline, proxy behavior.
- Не покрывает: parser-service internals, такие как execution adapters или browser automation.
- Зависит от: `03-data-layer-and-schema-ownership.md`.

## Обзор
Backend является control plane для sync с точки зрения admin UI, но не является непосредственным исполнителем parsing.

Текущее разделение:

- `service` владеет runtime config источников и фактическим выполнением `/sync/jobs`.
- `backend` владеет admin-facing metadata источников, политикой запуска sync, projection aggregate job, DB apply parsed items и recovery собственного runtime state.

Это формирует двухуровневую модель sync:

```text
Admin UI
  -> backend /sources and /jobs
  -> backend calls service /api/v1/sync/*
  -> backend polls service job events
  -> backend upserts products/source telemetry locally
  -> backend rebuilds category index after apply
```

## Сведение реестра источников
`app/api/v1/sources.py` предоставляет единое admin view, собранное из двух хранилищ:

1. список sources из `service` по пути `/api/v1/sync/sources`
2. строки профилей backend `ParserSource`

### Что дает service
- source key и URL
- флаг sync-enabled
- parser config, такой как mode и currency config

### Что дает backend
- persistent id source profile
- флаг enabled
- флаг hide-auto-added-products
- флаги show description/images
- supplier и promo settings
- telemetry последнего sync
- counts products

### Стратегия сопоставления
Backend сопоставляет source из service с локальным profile по:

- совпадению host URL
- `source key` против host URL
- `source key` против `profile name`

Это эвристическое сопоставление, а не жесткий FK contract.

## Ручной источник
Backend создает и управляет специальным local-only source:

- key: `__manual_admin_source__`
- name: `__manual_admin_source__`
- URL: `manual://admin/products`

Назначение:

- хранить manual products, созданные из admin UI;
- предоставлять synthetic row source в `/sources`;
- привязывать supplier/pricing behavior к manual catalog items.

Этот source принадлежит backend и не существует в `service`.

## Эндпоинты источников
Публикуемые admin endpoints:

| Endpoint | Поведение |
|---|---|
| `GET /api/v1/sources` | merged list: manual source + service sources, сопоставленные с backend profiles |
| `PATCH /sources/{key}/enabled` | только флаг backend profile |
| `PATCH /sources/{key}/sync-enabled` | forward в service, кроме manual source |
| `PATCH /sources/{key}/hide-auto-added-products` | флаг backend profile плюс локальное переписывание visibility products |
| `PATCH /sources/{key}/attribute-visibility` | `show_description` / `show_images` backend profile |
| `PATCH /sources/{key}/currency-priority` | валидация и forward в service config |
| `PATCH /sources/{key}/supplier` | backend supplier/promo settings |

### Побочный эффект переписывания visibility
Когда `hide_auto_added_products` изменяется, backend итерирует matching products и обновляет локально их статусы:

- скрытие auto-added items принудительно выставляет `status = "hidden"`;
- снятие скрытия восстанавливает status из availability variants для eligible products.

Это поведение живет прямо в router.

## Среда выполнения агрегированной синхронизации
`app/api/v1/jobs.py` реализует backend-specific слой aggregate jobs поверх jobs parser-service.

Важные части:

- in-memory `STATE` с latest aggregate job;
- persisted snapshot `SyncJobRuntime`;
- таблица `SyncAppliedBatch` для idempotent batch application;
- polling thread, запускаемый для каждого started aggregate job.

### Поток запуска
`POST /api/v1/jobs`

1. отклоняет запрос, если latest aggregate job имеет статус `pending`, `queued` или `in_progress`;
2. загружает список sources из service;
3. определяет target source keys:
   - явные request sources, если они переданы
   - иначе все sources service с `enabled=true` и `sync_enabled=true`
4. сортирует sources по last known sync duration из данных backend;
5. для sources service в manual mode строит `candidate_urls_by_source` из backend origin-variant data;
6. вызывает `service POST /api/v1/sync/jobs`;
7. создает id aggregate job backend в виде `agg-{timestamp}`;
8. сохраняет runtime и запускает daemon polling thread.

Точность outbound create-request:
- `sources` включается только когда у backend есть явное подмножество sources
- `candidate_urls_by_source` включается только когда backend действительно имеет manual-mode candidate URLs для отправки
- следовательно, backend-facing create flow использует optional outbound fields, а не полностью заполненную fixed request shape

### Поток latest
`GET /api/v1/jobs/latest`

- возвращает latest job из memory, если он есть;
- иначе перезагружает latest persisted runtime из DB и отображает его обратно в response payload.

### Поток cancel
`POST /api/v1/jobs/{job_id}/cancel`

- работает только для current latest aggregate job;
- best-effort пересылает cancel в `service`;
- локально помечает job backend как `cancelled` независимо от деталей upstream cancel response.

## Пайплайн опроса и применения
Polling thread - это место, где backend превращает события parser-service в локальное состояние.

Поведение на высоком уровне:

- polling job и endpoints events service каждые `2` seconds;
- трансляция source stages и progress в aggregate state;
- upsert products и origin variants в tables backend;
- tracking applied batches для защиты от duplicate application;
- обновление telemetry sync per-source;
- пометка missing products как unavailable, когда это требуется;
- backfill telemetry из history events;
- rebuild category index после завершения sync.

Apply logic находится прямо в `jobs.py`, а не в выделенном repository или background consumer.

## Восстановление persisted runtime
Startup вызывает `mark_interrupted_jobs_on_startup()`.

Назначение:

- проверить persisted rows sync runtime из предыдущей жизни процесса;
- корректно пометить interrupted aggregate jobs при startup backend;
- не оставлять видимое UI-состояние job навсегда в статусе "running" после restart container.

Текущие детали persisted coercion:
- backend переписывает persisted rows `queued` / `in_progress` в sentinel failed interruption при startup
- сохраняемая stage становится backend-local interruption marker, а не live stage parser-service
- некоторые aggregate jobs, которые terminally `failed` на уровне parser-service, все равно могут отдаваться backend как `completed`, если все failures связаны с password gate

Это восстановление является backend-local. Оно не перепривязывается к незавершенной job service как к полноценно resumable workflow.

## Проксирование service из router products
Помимо явных вызовов `/sync/*`, backend по-прежнему proxy'ит generic product routes в `service`.

Реализация в `products.py`:

- `GET /api/v1/products` сначала пытается выполнить proxy в service, затем fallback к локальному listing DB, если upstream падает.
- `api_route("/products", methods=_PROXY_ROOT_METHODS)` пересылает произвольные requests к корню products в `service`.
- `api_route("/products/{path:path}", methods=_PROXY_PATH_METHODS)` пересылает произвольные вложенные пути products, за исключением special-case `GET /products/{id}`, где вместо proxy используется локальная логика detail.

Это leftover compatibility layer, потому что текущий runtime `service` в основном публикует `/sync` routes, а backend все еще сохраняет более generic proxy surface.

## HTTP-контракт между backend и service
Текущие вызовы backend включают:

- `GET /api/v1/sync/sources`
- `PATCH /api/v1/sync/sources/{source_key}`
- `POST /api/v1/sync/jobs`
- `GET /api/v1/sync/jobs/{service_job_id}`
- `GET /api/v1/sync/jobs/{service_job_id}/events`
- `POST /api/v1/sync/jobs/{service_job_id}/cancel`
- requests product probe/proxy под `/api/v1/products...`

Все вызовы используют синхронный `requests` с явными timeouts.

## Текущие архитектурные последствия
- Владение sources разделено между DB backend и config file service.
- Синхронизация runtime является process-local для active polling, при этом в DB сохраняется только последнее состояние.
- Id aggregate job генерируются backend и отличаются от id jobs service.
- Orchestration jobs зависит от daemon threads внутри web/backend process, а не от отдельного queue worker.
- Admin controls источников - это не просто отражение состояния service; они также мутируют visibility backend catalog и metadata pricing.
