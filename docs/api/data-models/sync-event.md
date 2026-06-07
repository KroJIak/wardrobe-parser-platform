# Модель данных: Sync Event

## Область действия
Эта модель покрывает items event stream parser-service, возвращаемые `/api/v1/sync/jobs/{job_id}/events` и потребляемые sync-orchestration backend.

## Обертка события
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `event_id` | `string` | да | идентификатор события |
| `job_id` | `string` | да | id job service |
| `seq_no` | `int` | да | монотонно растущий cursor события |
| `type` | `string` | да | тип события |
| `ts` | `datetime-string` | да | timestamp события |
| `payload` | `object` | да | payload, специфичный для события |

Wrapper списка событий:

| Поле | Тип |
|---|---|
| `job_id` | `string` |
| `next_cursor` | `int` |
| `items` | `array<sync-event>` |

## Важные типы событий
Наблюдаются или явно обрабатываются в orchestration backend/service:

| Тип | Назначение |
|---|---|
| `job_started` | старт общей job |
| `source_started` | старт одного источника |
| `source_progress` | обновления stage/progress на уровне source |
| `product_batch` | нормализованный batch продуктов, эмитируемый для ingest backend |
| `source_finished` | завершение одного источника, включая failures |
| terminal job events | завершение job completed / failed / cancelled |

## Характеристики payload `product_batch`
Payload не объявлен одной Pydantic-моделью в backend. Текущий runtime ожидает:

- identifier batch
- context source key / source name
- список нормализованных product items
- subsets unavailable-product, если они эмитятся
- counters progress, используемые aggregate job state backend

Текущие gates forwarding и детали item:
- parser-service forwards только нормализованные items, у которых все еще есть `source_product_url`
- parser-service forwards только нормализованные items, у которых массив `variants[]` все еще непустой
- payload нормализованного item может содержать:
  - `canonical_url`
  - `external_id`
  - `unavailable_reason`
  - `buyer_total_price`
  - `buyer_service_fee`

## Представления по доменам
### `parser-service`
- `SyncEvent`
- `SyncEventsResponse`

### `backend`
- потребляется как generic `dict` payloads в `jobs.py`
- используется для:
  - обновления aggregate progress
  - применения deduplicated DB upserts
  - отметки applied batches
  - backfill telemetry

### `database`
- выделенной event-table нет
- idempotency batch отслеживается в `sync_applied_batch`

## Примечания по mapping
| Каноническое поле | `parser-service` | `backend` | `database` |
|---|---|---|---|
| `seq_no` | `seq_no` | используется как cursor | копируется в `SyncJobRuntime.event_cursor` |
| `product_batch` | event `payload` | потребляется для применения в DB | `sync_applied_batch` хранит только identity batch |

## Текущие ограничения
- Долговечность event stream ограничена памятью процесса parser-service.
- Backend рассматривает `product_batch` как единственный тип события, который управляет persistence каталога.
- Schema payload события частично неявна в коде и не опубликована как first-class standalone model.
- Пейлоады runtime богаче, чем один только верхнеуровневый список типов событий:
  - `source_started` несет index источника, total sources, attempt, stage code/label и progress percent
  - `source_progress` несет strategy, raw field counts, counters success/error products и progress percent
  - progress requeue может возвращать `stage = "source_requeued"` вместе с `max_attempts`
  - terminal payloads job могут содержать `reason`, `failed_sources`, `stage_code` и `stage_label`
