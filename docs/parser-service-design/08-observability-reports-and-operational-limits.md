# Архитектура parser-service: наблюдаемость, отчеты и операционные ограничения

## Область охвата
- Покрывает: логирование среды выполнения, подписки на события запуска, `SourceRunReport`, потоки sync-событий, поведение retry и requeue, а также жесткие операционные ограничения, видимые в текущем коде.
- Не покрывает: внешний стек мониторинга или представление состояния sync в UI на стороне backend.
- Зависит от: `service/app/services/run_logger.py`, `service/app/schemas/run_report.py`, `service/app/services/sync_orchestrator_service.py` и реализаций strategy/service, которые публикуют diagnostics.

## Модель логирования
Сервис использует логирование в стиле stdout, а не отдельный фреймворк структурированного логирования.

### Логи уровня приложения
`create_app()` настраивает:
- уровень `INFO`
- формат `%(asctime)s | %(levelname)s | %(name)s | %(message)s`

### Логи уровня запуска
`RunLogger` пишет plain-text строки вида:
- `[job=<run_id>] run_start source=...`
- `[job=<run_id>] [progress] shopify_js processed=...`

Эти логи и читаемы человеком, и переиспользуются как внутренний источник событий для progress callbacks оркестратора.

## Механизм подписки на прогресс
`RunLogger.strategy_event(...)` публикует callback payload, когда задан `run_id`.

Механика:
- callbacks хранятся в памяти процесса под `_SUBSCRIBERS`
- `subscribe_run_events(run_id, callback)` добавляет callback
- `unsubscribe_run_events(run_id, callback)` удаляет callback
- ошибки callback проглатываются, чтобы логирование не могло сломать parsing

`SyncOrchestratorService` использует этот механизм, чтобы преобразовывать прогресс strategy в runtime events типа `source_progress`.

## Артефакт SourceRunReport для диагностики одного запуска
`SourceRunReport` — это главный результат parser-service для синхронных source-run.

Диагностика, которую он несет:
- strategy attempts
- количество raw и parsed items
- quarantined URLs
- агрегирование unavailable reasons
- snapshots продуктов с отсутствующим весом
- counts по источнику веса
- строки ошибок
- длительность
- summary покрытия

Каждый `StrategyAttempt` может включать:
- `strategy`
- `success`
- `raw_count`
- `parsed_count`
- `error`
- `diagnostics`

Strategies заполняют diagnostics по мере возможности. Частые примеры:
- число страниц
- количество discovered candidates
- количество workers
- счетчики сбоев
- детали валютной политики
- browser-runner fetch counters

## Поток sync-событий как диагностический артефакт множественного запуска
Multi-source jobs добавляют еще один слой наблюдаемости:
- упорядоченный список `RuntimeEvent` в памяти процесса
- монотонно растущий `seq_no`
- типизированные payload
- текущий процент прогресса
- stage codes и stage labels

Это единственный живой поток событий, который сервис предоставляет наружу.

## Лимиты retry и requeue
### Повторы strategy внутри одного source-run
- управляются `source.config.retry_limits`
- применяются независимо для каждой strategy
- сбой записывается в `SourceRunReport.errors`

### Повторная постановка источника внутри одного orchestrated job
- жестко задан `max_source_requeues = 1`
- применяется и к:
  - `SourceRunReport.status == failed`
  - неожиданным exceptions во время выполнения источника

## Жесткие операционные ограничения текущего кода
| Ограничение | Текущее значение | Где обеспечивается |
|---|---|---|
| число workers у sync orchestrator | `1` | `sync.py` |
| число workers у probe orchestrator | `2` | `sync.py` |
| число активных bulk job slots | `1` | `SyncOrchestratorService.create_job()` |
| число source requeues | `1` | `SyncOrchestratorService._execute()` |
| размер страницы событий | `1..500` | route query validation |
| top products в source-run report | первые `10` valid products | `SourceRunService.run()` |
| max products в Shopify sitemap | до `50000` | валидация конфигурации и политики |

## Ограничения уровня процесса
- Job state исчезает при перезапуске процесса.
- История событий исчезает при перезапуске процесса.
- In-progress jobs после перезапуска не восстанавливаются.
- Горизонтальное масштабирование фрагментирует состояние job, потому что orchestrator не разделяются между экземплярами.
- Файловая конфигурация источников не имеет контроля конкурентности между несколькими экземплярами сервиса.

## Сценарии отказов, которые стоит считать первоклассными
### Сбои конфигурации
- отсутствует обязательная секция конфигурации
- невалидная валютная политика
- невалидная strategy в sequence
- отсутствует script path у browser runner

### Сбои доступа к storefront
- storefront закрыт паролем
- anti-bot и исчерпание HTTP retries
- некорректная полезная нагрузка ответа

### Сбои browser-среды выполнения
- отсутствует `node`
- отсутствует `chromium`
- отсутствует `Xvfb`
- таймаут runner
- ненулевой код завершения runner
- runner не выдал финальный JSON

### Сбои orchestrator/среды выполнения
- конфликт sync при наличии другой активной job
- отмена job в момент, когда источник еще завершает unwinding
- терминальная ошибка источника после одного requeue

## Чего текущий сервис не предоставляет
- Нет сохраненного журнала аудита.
- Нет эмиттера метрик или интеграции трассировки.
- Нет dead-letter queue или внешнего retry-планировщика.
- Нет явных request ID сверх того, что caller сам встраивает в `run_id`.
- Нет rate limiter или auth layer на самом sync API.

## Практические последствия для мониторинга
В текущей реализации операционная видимость зависит от совместного использования:
- логов контейнера
- синхронных payload `SourceRunReport`
- polled job status
- polled event streams

Этой комбинации достаточно, чтобы восстановить основной runtime path, но только пока процесс жив.
