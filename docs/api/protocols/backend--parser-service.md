# Протокол: `backend` ↔ `parser-service`

## Обзор

Этот протокол определяет активное runtime-взаимодействие между `backend` и `parser-service`.

| Аспект | Текущая реализация |
|---|---|
| Транспорт | internal HTTP/1.1 JSON REST |
| Caller from backend | `httpx`-based service clients и proxy helpers |
| Caller from parser-service | `httpx`-based weight-rules client |
| Долговременное состояние на стороне service | `config/sources.json` |
| Состояние runtime на стороне service | in-memory job execution, source config file и in-memory sync events |

Живой межсервисный протокол сосредоточен вокруг `/api/v1/sync/*` плюс одного reverse-read контракта для parser weight rules.

## Направление A: backend → parser-service

### 1. Зеркало registry источников

| Method | Path на parser-service | Использование backend |
|---|---|---|
| `GET` | `/api/v1/sync/sources` | построение aggregate-списка источников в backend `/api/v1/sources` |
| `PATCH` | `/api/v1/sync/sources/{source_key}` | изменение source flags и currency strategy в parser-service |
| `POST` | `/api/v1/sync/sources/{source_key}/run` | запуск одного источника из backend-owned tools |

#### Структура запроса для `PATCH /sync/sources/{source_key}`

Сейчас parser-service принимает такие изменяемые поля:

- `enabled: bool | null`
- `sync_enabled: bool | null`
- `requested_currency_priority: list[str] | null`
- `currency_method: str | null`
- `locked_currency: str | null`

Значение на стороне backend:

- поля профиля источника на стороне backend, такие как `supplier_id`, `promo_factor`, `hide_auto_added_products` и display flags, остаются в ownership backend в PostgreSQL;
- изменяемые поля parser-service влияют только на `config/sources.json` parser-service.

### 2. Контракт multi-source sync job

| Method | Path на parser-service | Использование backend |
|---|---|---|
| `POST` | `/api/v1/sync/jobs` | запуск sync run в parser-service |
| `GET` | `/api/v1/sync/jobs/latest` | polling последнего service-side sync job |
| `GET` | `/api/v1/sync/jobs/{job_id}` | чтение одного service-side sync job |
| `GET` | `/api/v1/sync/jobs/{job_id}/events` | потребление event stream |
| `POST` | `/api/v1/sync/jobs/{job_id}/cancel` | запрос на отмену |

#### Запрос создания job

Схема parser-service сейчас принимает:

| Поле | Тип | Примечания |
|---|---|---|
| `triggered_by` | `str` | по умолчанию `"manual"` |
| `dry_run` | `bool` | по умолчанию `false` |
| `sources` | `list[str]` | пустой список означает "все enabled и sync-enabled источники" |
| `candidate_urls_by_source` | `dict[str, list[str]]` | необязательные manual candidate URLs, сгенерированные backend |

Текущее поведение backend:

1. Предотвращает параллельные aggregate jobs через backend-side `409 sync already in progress`.
2. Собирает eligible source keys, сортирует их по предыдущей длительности sync и может прикрепить `candidate_urls_by_source`.
3. Отправляет запрос в parser-service.
4. Сохраняет собственный aggregate job id в runtime state backend.
5. Асинхронно опрашивает статус и события parser-service job.

#### Ответ на создание job

Parser-service возвращает:

- `job_id`
- `status`
- `created_at`

Backend рассматривает возвращенный `job_id` как `service_job_id` и создает отдельный backend aggregate id вида `agg-{timestamp}`.

### 3. Контракт probe job

| Method | Path на parser-service | Использование backend |
|---|---|---|
| `POST` | `/api/v1/sync/probe/jobs` | probe product URL |
| `GET` | `/api/v1/sync/probe/jobs/latest` | последний probe job |
| `GET` | `/api/v1/sync/probe/jobs/{job_id}` | конкретный probe job |
| `GET` | `/api/v1/sync/probe/jobs/{job_id}/events` | event stream probe |
| `POST` | `/api/v1/sync/probe/jobs/{job_id}/cancel` | отмена probe job |

Сейчас probe request parser-service включает:

- `product_url: str`
- `dry_run: bool = false`

### 4. Контракт event stream

Endpoints событий parser-service возвращают:

- `job_id`
- `next_cursor`
- `items: list[SyncEvent]`

Каждый item события содержит:

- `event_id`
- `job_id`
- `seq_no`
- `type`
- `ts`
- `payload`

Наблюдаемая зависимость backend от типов событий:

| Тип события | Использование backend |
|---|---|
| `job_started` | инициализация aggregate runtime state |
| `source_started` | отметка активного источника |
| `source_progress` | обновление stage/progress |
| `product_batch` | применение parsed products в backend-owned catalog tables |
| `source_finished` | обновление telemetry источника в backend DB |
| terminal job event | финализация aggregate runtime state |

`product_batch` является критической точкой передачи ingest. Parser-service эмитит нормализованные parsed items; backend сохраняет их в собственную схему каталога и обновляет category/dedup/index state.

Текущее богатство payload сверх верхнеуровневого списка событий:
- `source_started` несет порядковый номер источника, число попыток, stage code/label и progress percent
- `source_progress` несет имя strategy, raw counters полей, counters success/error и progress percent
- прогресс requeue может возвращать `stage = "source_requeued"` вместе с `max_attempts`
- terminal job events могут нести `reason`, `failed_sources`, `stage_code` и `stage_label`
- forwarding `product_batch` фильтруется так, что downstream эмитятся только items с `source_product_url` и непустыми `variants`

## Направление B: parser-service → backend

### Контракт parser для weight-rules

| Method | Path на backend | Использование parser-service |
|---|---|---|
| `GET` | `/api/v1/public/parser-contract/weight-rules` | обогащение parsed products сконфигурированными weight rules |

Текущее разделение ownership:

- backend владеет authoring и storage weight rules;
- parser-service никогда не записывает weight rules;
- parser-service получает контракт по HTTP во время выполнения source;
- parser-service деградирует к пустым rules при ошибке получения.

## Таймауты и преобразование отказов

Наблюдаемое поведение клиентов:

| Caller | Обработка отказов |
|---|---|
| backend → parser-service APIs источников | преобразует ошибки запроса в `502 Bad Gateway` с `detail` |
| backend → запуск job в parser-service | преобразует ошибки в `502 Bad Gateway`; параллельный aggregate sync backend становится `409` до outbound-вызова |
| backend → cancel в parser-service | best-effort; backend все равно может отметить aggregate job как cancelled, даже если вызов cancel в service не удался |
| parser-service → weight-rules backend | ошибка не прерывает startup service; runtime откатывается к отсутствию rules |

Тела ошибок на обеих сторонах являются JSON и для HTTP exceptions сосредоточены вокруг `detail`.

Оговорка по probe-cancel:
- routes cancel и status для sync реализуют явную обработку not-found
- route cancel для probe в inspected parser-service не реализует такую же явную ветку `404` для отсутствующей job

## Границы контракта

### Чем владеет backend

- lifecycle aggregate sync, публикуемый admin UI;
- долговременная sync telemetry в database backend;
- ingest parser output в продукты, variants, categories, dedup decisions и telemetry источников;
- admin-friendly projection источников, объединяющая service source config с DB source profiles backend.

### Чем владеет parser-service

- parser execution strategies и adapters;
- file-backed registry источников в `config/sources.json`;
- in-process job state и event stream;
- one-off run reports и runtime probe.

## Известные hybrid и stale edges

### Прокси-поверхность продуктов в backend

Backend все еще публикует generic proxy endpoints, которые проксируют `/api/v1/products` и `/api/v1/products/{path}` в parser-service.

Текущая inspected API surface parser-service содержит только `/api/v1/sync/*`.

Это означает:

- proxy path существует в backend;
- frontend все еще вызывает некоторые proxy-style product routes, такие как `/api/v1/products/add-by-url`;
- в текущем runtime parser-service не подтвержден соответствующий HTTP route.

Этот edge является частью реализованной contract surface backend, но не обеспечен подтвержденным live route parser-service в inspected service code.

## Последовательность runtime

```text
Admin UI
  -> backend POST /api/v1/jobs

backend
  -> POST service /api/v1/sync/jobs
  <- {job_id, status, created_at}
  -> poll GET /api/v1/sync/jobs/{job_id}
  -> poll GET /api/v1/sync/jobs/{job_id}/events
  <- product_batch events
  -> persist products, variants, sync runtime, source telemetry
  -> expose aggregate status to frontend /api/v1/jobs/latest

service
  -> GET backend /api/v1/public/parser-contract/weight-rules
  <- current weight-rule contract
```
