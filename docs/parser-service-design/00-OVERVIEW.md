# Проектирование parser-service

## Назначение
`parser-service` — это выделенная FastAPI-среда выполнения для парсинга storefront-источников и оркестрации sync-процессов. Он владеет конфигурацией выполнения парсеров, отчетами отдельных запусков и состоянием sync-job/event в памяти процесса; основной путь записи в базу каталога ему не принадлежит.

## Область охвата
- Покрывает: запуск сервиса, маршруты `/api/v1/sync/*`, файловый реестр источников, среду выполнения адаптеров и стратегий, browser runner, зависимость от backend weight-rule и операционные ограничения.
- Не покрывает: backend-персистентность каталога, обогащенный профиль источника для admin, поведение frontend polling и владение database DDL.
- Зависит от: `service/app/*`, `service/browser_runner/*`, `service/config/sources.json` и backend public parser-contract endpoint.

## Архитектура среды выполнения
```text
HTTP
  |
  v
FastAPI app
  |
  +-- /health
  `-- /api/v1/sync/*
        |
        +-- SourceRunServiceFactory
        |     |
        |     +-- SourceRepository (config/sources.json)
        |     +-- AdapterRegistry
        |     +-- StrategyRegistry
        |     `-- WeightRulesClient -> backend
        |
        +-- SourceRunService
        |     |
        |     +-- discovery
        |     +-- выполнение стратегии
        |     +-- adapter normalization/validation
        |     `-- SourceRunReport
        |
        `-- SyncOrchestratorService
              |
              +-- RuntimeJob / RuntimeEvent
              +-- ThreadPoolExecutor
              `-- эмиссия события product_batch
```

## Ключевые обязанности
- Предоставлять узкий sync API для списка источников, patch-обновления источников, source-run, sync-job, probe-job, статуса job, job events и отмены.
- Загружать конфигурацию парсинга источников из `config/sources.json`, включая порядок стратегий, лимиты повторов, таймауты, валютную политику и настройки browser runner.
- Выполнять source-specific parsing через adapters и strategies, обогащать отсутствующий вес из backend rules и формировать `SourceRunReport`.
- Агрегировать source-run в process-local multi-source jobs с event streams, пригодными для backend ingestion.
- Запускать Node/Chromium/Xvfb browser automation для источников, которым нужен browser fallback.

## Явные не-обязанности
- В проверенном runtime-коде не найдено подтвержденного активного SQLAlchemy session, ORM model или пути персистентности в базу.
- Прямая API-поверхность для frontend отсутствует; frontend идет через backend.
- Устойчивого хранилища заданий, брокера очередей или журнала повторного воспроизведения сверх текущей памяти процесса нет.
- Несмотря на установленные SQLAlchemy и Alembic, работающий сервис не владеет активными миграциями схемы.

## Текущая модель выполнения
- Приложение сервиса создается один раз через `app/main.py -> create_app()`.
- Каждый HTTP-запрос строит свежий `SourceRunService` через `SourceRunServiceFactory`.
- В `app/api/v1/sync.py` существуют два глобальных экземпляра orchestrator:
  - `sync_orchestrator = SyncOrchestratorService(max_workers=1)`
  - `probe_orchestrator = SyncOrchestratorService(max_workers=2)`
- Состояние job живет внутри этих экземпляров orchestrator в памяти только в течение жизни процесса.

## Индекс документов
| # | Файл | Назначение | Зависит от |
|---|------|------------|-----------|
| 00 | `00-OVERVIEW.md` | Карта домена, границы, порядок чтения | - |
| 01 | `01-project-setup-and-runtime-dependencies.md` | Запуск, env, Docker, упакованная среда выполнения | 00 |
| 02 | `02-source-registry-and-configuration-model.md` | Владение `sources.json` и модель конфигурации | 01 |
| 03 | `03-sync-api-and-orchestrator-runtime.md` | HTTP API и job в памяти процесса | 01, 02 |
| 04 | `04-source-run-pipeline.md` | Поток выполнения одного источника и генерация отчета | 02, 03 |
| 05 | `05-adapters-and-strategy-selection.md` | Контракты adapter/strategy и wiring реестров | 02, 04 |
| 06 | `06-browser-runner-and-automation.md` | Путь browser automation и контракт runner | 01, 05 |
| 07 | `07-backend-contracts-and-weight-enrichment.md` | Интеграция с backend и межсервисные зависимости полезной нагрузки | 03, 04, 06 |
| 08 | `08-observability-reports-and-operational-limits.md` | Логи, отчеты, повторы, ограничения, режимы отказа | 03, 04, 07 |

## Порядок чтения
1. Начать с `01`, чтобы понять форму среды выполнения и то, что реально разворачивается.
2. Прочитать `02` перед `03` и `04`, потому что почти все поведение управляется source config.
3. Прочитать `03`, чтобы понять внешнюю HTTP-поверхность и модель оркестрации.
4. Прочитать `04` и `05` вместе, чтобы понять, как source run выполняется от начала до конца.
5. Прочитать `06` и `07`, чтобы понять не-Python интеграции, влияющие на корректность среды выполнения.
6. Завершить `08` для отчетов, событий, операционных потолков и обработки сбоев.

## Ключевые правила проектирования в текущем коде
- Сервис — это специализированная среда выполнения парсера, а не универсальный product API.
- Конфигурация источников хранится в файле и изменяется in place через sync API.
- Регистрация adapter и strategy явная и централизована в `SourceRunServiceFactory`.
- Оркестрация job намеренно привязана к одному процессу; внешней очереди или слоя персистентности в проверенном кодовом пути нет.
- Интеграция с backend обязательна для живого обогащения weight-rule, но при сбое вызова сервис деградирует до пустого набора rules.

## Междоменные зависимости
- Backend -> service: `/api/v1/sync/sources`, `/jobs`, `/probe/jobs`, `/events`, `/cancel`.
- Service -> backend: `GET /api/v1/public/parser-contract/weight-rules`.
- Разделяемые schema concepts, используемые здесь: source flags, sync job status, sync events, parser products и weight rules.
