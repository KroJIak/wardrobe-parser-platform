# Модель данных: Sync Job

## Область действия
Эта модель покрывает envelopes sync/probe jobs со стороны service, aggregate sync runtime backend и payload progress в frontend-admin.

## Запрос создания service job
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `triggered_by` | `string` | да | по умолчанию `manual` |
| `dry_run` | `bool` | да | флаг parser dry run |
| `sources` | `array<string>` | нет | выбранные source keys, когда backend не хочет, чтобы parser service сам выводил все eligible enabled sources |
| `candidate_urls_by_source` | `object<string, array<string>>` | нет | принудительные candidate URLs для manual-mode sources, когда backend ими располагает |

## Ответ на создание service job
| Поле | Тип |
|---|---|
| `job_id` | `string` |
| `status` | `string` |
| `created_at` | `datetime-string` |

## Ответ со статусом service job
| Поле | Тип |
|---|---|
| `job_id` | `string` |
| `status` | `string` |
| `created_at` | `datetime-string` |
| `started_at` | `datetime-string \| null` |
| `finished_at` | `datetime-string \| null` |
| `current_source_name` | `string \| null` |
| `current_source_index` | `int` |
| `total_sources` | `int` |
| `current_strategy` | `string \| null` |
| `current_stage` | `string \| null` |
| `products_success` | `int` |
| `products_error` | `int` |
| `progress_percent` | `float` |
| `can_cancel` | `bool` |
| `error` | `string \| null` |

## Структура latest job aggregate backend
Используется frontend как `latestJob`.

| Поле | Тип |
|---|---|
| `job_id` | `string` |
| `status` | `string` |
| `created_at` | `datetime-string` |
| `started_at` | `datetime-string \| null` |
| `completed_at` | `datetime-string \| null` |
| `next_scheduled_at` | `datetime-string \| null` |
| `total_products` | `int \| null` |
| `new_products` | `int` |
| `updated_products` | `int` |
| `new_images` | `int` |
| `total_sources` | `int` |
| `processed_sources` | `int` |
| `progress_percent` | `float` |
| `processed_products` | `int` |
| `expected_products` | `int` |
| `failed_products` | `int` |
| `products_progress_percent` | `float` |
| `current_source_name` | `string \| null` |
| `current_source_parser_type` | `string \| null` |
| `current_strategy_index` | `int` |
| `current_strategy_total` | `int` |
| `current_source_index` | `int` |
| `current_stage` | `string \| null` |
| `current_source_processed_products` | `int` |
| `current_source_total_products` | `int` |
| `current_product_title` | `string \| null` |
| `site_products_total` | `int` |
| `can_cancel` | `bool` |
| `sync_period_minutes` | `int` |

## Структуры history/detail
### История элементов
`SyncJobHistoryItem`:

- `id`
- `status`
- `triggered_by`
- `created_at`
- `started_at`
- `completed_at`
- `total_products`
- `new_products`
- `updated_products`
- `new_images`
- `error_count`
- `http_429_count`
- `http_5xx_count`

### Расширение detail
`SyncJobDetails = SyncJobHistoryItem + source_runs[]`

Поля `SourceRunItem`:

- `id`
- `source_id`
- `status`
- `products_discovered`
- `products_fetched`
- `products_failed`
- `error_message`
- `discovery_mode`
- `started_at`
- `completed_at`

## Представления по доменам
### `frontend`
- `JobsLatest`
- `SyncJobHistoryItem`
- `SyncJobDetails`
- `SourceRunItem`

### `backend`
- in-memory `AggregateJob`
- row persistence в DB `SyncJobRuntime`

### `parser-service`
- `SyncJobCreateRequest`
- `SyncJobCreateResponse`
- `SyncJobStatusResponse`

### `database`
- `sync_job_runtime`
- `sync_applied_batch`

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `parser-service` | `database` |
|---|---|---|---|---|
| primary id | `job_id` или `id` в зависимости от view | id aggregate job | id service job | `aggregate_job_id`, `service_job_id` |
| текст stage | human-readable string | форматируется backend | raw stage code/label | `current_stage`, сохраняемый backend |
| progress | percentages | вычисляется backend | эмитится service | не сохраняется как итоговый percent |

## Текущие ограничения
- Parser-service хранит jobs и events только в памяти.
- Backend создает собственный aggregate job id и связывает его с id service job.
- Backend сохраняет только последнее runtime-oriented state, а не полный нормализованный event log.
- Recovery на startup backend переписывает прерванные persisted aggregate jobs в sentinel локального backend failure об interruption.
- Backend может показывать некоторые terminal failures parser-service как aggregate results `completed`, когда все failures связаны только с password gate.
