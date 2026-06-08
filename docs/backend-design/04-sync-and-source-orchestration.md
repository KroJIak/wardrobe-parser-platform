# Архитектура Backend: Sync и Оркестрация Источников

## Область
- Покрывает: агрегацию backend поверх parser-service, merge source registry, lifecycle sync job, apply pipeline, proxy behavior.
- Не покрывает: parser-service internals, такие как execution adapters или browser automation.
- Зависит от: `03-data-layer-and-schema-ownership.md`.

## Обзор
Backend является control plane для sync с точки зрения admin UI, но не является непосредственным исполнителем parsing.

Текущее разделение:
- `service` владеет runtime config источников и фактическим выполнением `/sync/jobs`
- `backend` владеет admin-facing metadata источников, политикой запуска sync, projection aggregate job, DB apply parsed items и recovery собственного runtime state

## Сведение реестра источников
`app/api/v1/sources.py` предоставляет единое admin view, собранное из двух хранилищ:
1. списка sources из `service` по пути `/api/v1/sync/sources`
2. строк профилей backend `ParserSource`

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
Backend всегда публикует специальный local-only source:
- key: `__manual_admin_source__`
- display name: `Личный каталог`
- materialized URL в БД: `manual://admin/products`

Назначение:
- хранить manual products, созданные из admin UI
- предоставлять synthetic row source в `/sources`
- привязывать supplier/pricing behavior к manual catalog items

Этот source не существует в `service`.

### Виртуальная и материализованная формы
Текущее поведение двуступенчатое:
- пока supplier не назначен, manual source возвращается как виртуальный item без строки `parser_source`
- при `PATCH /sources/__manual_admin_source__/supplier` backend создает реальную строку `ParserSource`

Если дальнейшая операция требует уже существующую materialized row, а ее еще нет, backend возвращает `409` с требованием сначала назначить тариф для личного каталога.

## Эндпоинты источников
Публикуемые admin endpoints:

| Endpoint | Поведение |
|---|---|
| `GET /api/v1/sources` | merged list: virtual/materialized manual source + service sources, сопоставленные с backend profiles |
| `PATCH /sources/{key}/enabled` | только флаг backend profile |
| `PATCH /sources/{key}/sync-enabled` | forward в service, кроме manual source |
| `PATCH /sources/{key}/hide-auto-added-products` | флаг backend profile плюс локальное переписывание visibility products |
| `PATCH /sources/{key}/attribute-visibility` | `show_description` / `show_images` backend profile |
| `PATCH /sources/{key}/currency-priority` | валидация и forward в service config |
| `PATCH /sources/{key}/supplier` | backend supplier/promo settings; materializes manual source при необходимости |

### Побочный эффект переписывания visibility
Когда `hide_auto_added_products` изменяется, backend итерирует matching products и обновляет локально их статусы:
- скрытие auto-added items принудительно выставляет `status = "hidden"`
- снятие скрытия восстанавливает status из availability variants для eligible products

Это поведение живет прямо в router.

## Среда выполнения агрегированной синхронизации
`app/api/v1/jobs.py` реализует backend-specific слой aggregate jobs поверх jobs parser-service.

Важные части:
- in-memory `STATE` с latest aggregate job
- persisted snapshot `SyncJobRuntime`
- таблица `SyncAppliedBatch` для idempotent batch application
- polling thread, запускаемый для каждого started aggregate job

### Поток запуска
`POST /api/v1/jobs`

1. отклоняет запрос, если latest aggregate job имеет статус `pending`, `queued` или `in_progress`
2. загружает список sources из service
3. определяет target source keys
4. сортирует sources по last known sync duration из данных backend
5. для sources service в manual mode строит `candidate_urls_by_source` из backend origin-variant data
6. вызывает `service POST /api/v1/sync/jobs`
7. создает id aggregate job backend в виде `agg-{timestamp}`
8. сохраняет runtime и запускает daemon polling thread

## Пайплайн опроса и применения
Polling thread - это место, где backend превращает события parser-service в локальное состояние.

Поведение на высоком уровне:
- polling job и endpoints events service каждые `2` seconds
- трансляция source stages и progress в aggregate state
- upsert products и origin variants в tables backend
- tracking applied batches для защиты от duplicate application
- обновление telemetry sync per-source
- пометка missing products как unavailable, когда это требуется
- backfill telemetry из history events
- rebuild category index после завершения sync

Apply logic находится прямо в `jobs.py`, а не в выделенном repository или background consumer.

## Восстановление persisted runtime
Startup вызывает `mark_interrupted_jobs_on_startup()`.

Назначение:
- проверить persisted rows sync runtime из предыдущей жизни процесса
- корректно пометить interrupted aggregate jobs при startup backend
- не оставлять видимое UI-состояние job навсегда в статусе `running` после restart container

## Проксирование service из router products
Помимо явных вызовов `/sync/*`, backend по-прежнему proxy'ит generic product routes в `service`.

Реализация в `products.py`:
- `GET /api/v1/products` сначала пытается выполнить proxy в service, затем fallback к локальному listing DB
- `api_route("/products", methods=_PROXY_ROOT_METHODS)` пересылает произвольные requests к корню products в `service`
- `api_route("/products/{path:path}", methods=_PROXY_PATH_METHODS)` пересылает произвольные вложенные пути products, за исключением `GET /products/{id}`, где используется локальная логика detail

## Текущие архитектурные последствия
- Владение sources разделено между DB backend и config file service.
- Синхронизация runtime является process-local для active polling, при этом в DB сохраняется только последнее состояние.
- Id aggregate job генерируются backend и отличаются от id jobs service.
- Orchestration jobs зависит от daemon threads внутри web/backend process.
- Admin controls источников - это не просто отражение состояния service; они также мутируют visibility backend catalog и metadata pricing.
