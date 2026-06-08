# Архитектура parser-service: sync API и оркестратор среды выполнения

## Область охвата
- Покрывает: маршруты `/api/v1/sync/*`, модели запросов и ответов, правила создания sync-job, ход probe-job, поток событий, вычисление статусов и поведение orchestrator в памяти процесса.
- Не покрывает: логику нормализации на уровне отдельного продукта и детали извлечения для конкретных storefront.
- Зависит от: `service/app/api/v1/sync.py`, `service/app/services/sync_orchestrator_service.py`, `service/app/schemas/sync_contract.py` и `service/app/schemas/sync_stages.py`.

## Поверхность HTTP
Все parser-маршруты живут под `/api/v1/sync`.

| Метод | Путь | Назначение |
|---|---|---|
| `GET` | `/api/v1/sync/sources` | вернуть записи реестра источников со стороны сервиса |
| `PATCH` | `/api/v1/sync/sources/{source_key}` | изменить верхнеуровневые флаги и выбранные валютные настройки |
| `POST` | `/api/v1/sync/sources/{source_key}/run` | синхронно запустить один источник и вернуть `SourceRunReport` |
| `POST` | `/api/v1/sync/jobs` | создать multi-source async sync-job |
| `GET` | `/api/v1/sync/jobs/latest` | вернуть статус последней sync-job |
| `GET` | `/api/v1/sync/jobs/{job_id}` | вернуть статус одной sync-job |
| `GET` | `/api/v1/sync/jobs/{job_id}/events` | вернуть постраничные события среды выполнения |
| `POST` | `/api/v1/sync/jobs/{job_id}/cancel` | запросить отмену |
| `POST` | `/api/v1/sync/probe/jobs` | создать probe-job для одного product URL |
| `GET` | `/api/v1/sync/probe/jobs/latest` | вернуть статус последней probe-job |
| `GET` | `/api/v1/sync/probe/jobs/{job_id}` | вернуть статус одной probe-job |
| `GET` | `/api/v1/sync/probe/jobs/{job_id}/events` | вернуть постраничные probe events |
| `POST` | `/api/v1/sync/probe/jobs/{job_id}/cancel` | отменить probe-job |

В текущем inspected коде на эту поверхность не навешаны отдельные auth middleware, API key или rate limiter: маршруты полагаются только на сетевую изоляцию и backend-facing размещение.

## Модели запросов и ответов
### Запрос на patch источника
Поля:
- `enabled: bool | null`
- `sync_enabled: bool | null`
- `requested_currency_priority: list[str] | null`
- `currency_method: str | null`
- `locked_currency: str | null`

### Запрос на создание sync-job
Поля из `SyncJobCreateRequest`:
- `triggered_by: str = "manual"`
- `dry_run: bool = false`
- `sources: list[str] = []`
- `candidate_urls_by_source: dict[str, list[str]] = {}`

### Запрос probe product
Поля:
- `product_url: str`
- `dry_run: bool = false`

### Ответ со статусом
`SyncJobStatusResponse` содержит:
- идентификатор job и timestamps
- текущий источник и стратегию
- текст текущей стадии
- счетчики успешных и ошибочных продуктов
- процент прогресса
- возможность отмены
- terminal error text

### Ответ со списком событий
`SyncEventsResponse` возвращает:
- `job_id`
- `next_cursor`
- `items[]` из `SyncEvent`

## Глобальные экземпляры orchestrator
`sync.py` создает два orchestrator на уровне модуля:

| Имя | Максимум workers | Предназначение |
|---|---|---|
| `sync_orchestrator` | `1` | bulk и обычные sync jobs |
| `probe_orchestrator` | `2` | probe-jobs для одного продукта |

Поскольку это глобальные объекты модуля, их состояние job разделяется между запросами в рамках одного процесса и сбрасывается при перезапуске процесса.

## Правила создания sync-job
### Выбор источников
- маршрут загружает все источники из `SourceRepository`
- источники с `enabled && sync_enabled` образуют пул по умолчанию
- если `payload.sources` пуст, job запускает все доступные на текущий момент источники
- если `payload.sources` передан, явный запуск по списку разрешен даже для источников, которые не включены или не sync-enabled, если ключ существует

### Кандидатные URL по источникам
- сохраняются только ключи, попавшие в итоговый список источников
- сохраняются только значения типа list
- URL подрезаются по краям и дедуплицируются с сохранением входного порядка

### Правило конфликта
`SyncOrchestratorService.create_job(...)` отклоняет новую работу, если его собственная active job все еще находится в `queued` или `in_progress`, выбрасывая `RuntimeError("sync already in progress")`, который маршрут отображает в HTTP `409`.

Это правило применяется независимо для каждого orchestrator instance:
- одна активная bulk sync-job
- не более одной активной probe-job на состояние probe orchestrator, хотя сам probe executor имеет два потока после принятия jobs

## Ход probe-job
Probe-маршрут:
1. нормализует host запрошенного product URL
2. сканирует все источники
3. сопоставляет по:
   - нормализованному host из `source.url`
   - необязательным `config.source_domains`
4. создает single-source job с candidate URLs, принудительно установленными в переданный product URL
5. оборачивает итоговый `SourceRunReport` в `_filter_report_by_product_url(...)`

Правила фильтрации:
- предпочитается точное совпадение нормализованного URL
- host должен совпадать
- для Shopify-like URL допустимо совпадение по handle
- для URL Vinted допустимо совпадение по item id

Если отфильтрованный отчет содержит:
- валидные продукты -> `success`
- только unavailable products -> `partial`
- ни того ни другого -> `failed`

## Состояние job во время выполнения
`RuntimeJob` хранит:
- `job_id`
- `status`
- timestamps
- `dry_run`
- `source_keys`
- `source_candidate_urls`
- текущий источник, стратегию и стадию
- счетчики success/error
- флаг отмены
- список событий
- число обработанных источников
- текущий процент прогресса

`RuntimeEvent` хранит:
- идентификатор события
- sequence number
- тип события
- UTC timestamp
- произвольный payload dict

## Наблюдаемые типы событий
- `job_started`
- `source_started`
- `source_progress`
- `product_batch`
- `source_finished`
- `job_finished`
- `job_failed`
- `job_cancelled`

## Модель стадий и прогресса
### Коды стадий
Сервис определяет коды контракта, такие как:
- `source_prepare`
- `discover_products`
- `discover_done`
- `fetch_start`
- `fetch_progress`
- `fetch_skip`
- `export_products`
- `strategy_run`
- `source_done`
- `source_failed`
- `job_done`
- `job_failed`
- `job_cancelled`

### Пользовательские подписи стадий
`STAGE_LABEL_RU` сопоставляет этим кодам русские подписи. Orchestrator также синтезирует более специфичные подписи для raw strategy progress strings, например:
- `live_dom*`
- `export progress*`
- `sitemap *`
- `phase=*`

### Вычисление прогресса
- каждый источник дает равную долю общего прогресса job
- прогресс стратегии может инкрементально обновлять долю текущего источника
- глобальный прогресс монотонен и никогда не уменьшается
- терминальные статусы принудительно задают `progress_percent = 100.0` в ответах маршрутов

## Семантика отмены
`cancel(job_id)` ведет себя не так, как устойчивая очередь задач:
- если job уже terminal, он возвращает текущее состояние без изменений
- если job активна, метод сразу:
  - ставит `cancel_requested = True`
  - меняет статус на `cancelled`
  - проставляет `finished_at`
  - очищает `_active_job_id`
  - добавляет событие `job_cancelled`

Такое немедленное освобождение активного слота позволяет стартовать новой job, даже если текущее выполнение источника еще продолжает сворачиваться в фоне.

## Поведение requeue
Внутри `_execute(...)`:
- `max_source_requeues = 1`
- и failed source reports, и выброшенные exceptions могут запустить один requeue
- вторая неудача становится terminal для этого источника

## Пагинация событий
`get_events(job_id, cursor, limit)`:
- фильтрует события с `seq_no > cursor`
- ограничивает ответ значением `limit`
- возвращает `next_cursor`, равный последнему доставленному sequence number

Устойчивое хранилище курсоров отсутствует; клиенты должны управлять курсорами самостоятельно.

## Наблюдаемая асимметрия маршрутов отмены
- `POST /jobs/{job_id}/cancel` явно возвращает `404`, если bulk job не найдена.
- `POST /probe/jobs/{job_id}/cancel` в текущем коде не делает такого guard-check перед сборкой ответа, поэтому неизвестный `job_id` может привести не к аккуратному `404`, а к серверной ошибке.
