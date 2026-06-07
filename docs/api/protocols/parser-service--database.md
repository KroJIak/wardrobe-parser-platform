# Протокол: `parser-service` ↔ `database`

## Обзор

Этот файл фиксирует текущий database-контракт для модуля `parser-service` ровно в той форме, в какой он реализован.

Подтвержденный runtime-контракт таков: в inspected application code `parser-service` не реализован активный прямой database-протокол.

## Текущее состояние

| Аспект | Наблюдаемая реализация |
|---|---|
| `DATABASE_URL` в environment | присутствует |
| Пакеты SQLAlchemy/Alembic | присутствуют в зависимостях service |
| Фабрика DB session в активном runtime | не найдена в inspected app code service |
| ORM model layer в активном runtime | не найден |
| Прямые SQL queries в активном runtime | не найдены |
| Миграции DB, выполняемые container service | не найдены; `service-db-init` в compose является no-op |
| Долговременное storage parser-service | file-backed `config/sources.json` |
| Хранение jobs/events | только в памяти процесса |

## Эффективный контракт хранения

### Что parser-service сохраняет сегодня

| Данные | Механизм хранения |
|---|---|
| Registry источников и parser config | JSON-файл `config/sources.json` |
| Job'ы runtime | память процесса внутри `SyncOrchestratorService` |
| События runtime | память процесса внутри `SyncOrchestratorService` |
| Результат one-off run | только в HTTP response |

### Что parser-service не сохраняет напрямую

| Семейство данных | Текущий статус |
|---|---|
| Parsed products | parser-service не пишет в DB |
| Parser source profile rows в схеме backend | parser-service не пишет |
| Weight rules | только чтение через HTTP-контракт backend |
| Таблицы sync runtime в схеме backend | parser-service не пишет |
| Данные categories, dedup, pricing, showcase, auth | parser-service не трогает |

## Подтвержденное runtime-поведение

### Хранение source config

`SourceRepository` является file-backed и по умолчанию использует `config/sources.json`.

Текущий mutation path:

1. service получает `PATCH /api/v1/sync/sources/{source_key}`;
2. service переписывает source flags и выбранные поля currency config;
3. обновленные значения сохраняются обратно в `sources.json`.

Никакая строка database не обновляется в рамках этого flow.

### Выполнение sync

`SyncOrchestratorService` хранит:

- `_jobs`
- `_active_job_id`
- `_latest_job_id`

только в памяти процесса.

Следствия текущего контракта:

- перезапуски service теряют in-memory state jobs и events;
- backend не может восстановить runtime state parser-service из PostgreSQL;
- backend должен рассматривать parser-service как execution worker, а не как домен долговременного хранения.

### Передача продуктов

Parsed products пересекают границу service через HTTP event payloads, такие как `product_batch`.

Долговечность начинается только тогда, когда backend потребляет эти события и записывает их в backend-owned tables.

## Поверхности, которые существуют, но не являются активным DB-поведением

Следующие факты присутствуют в репозитории, но не образуют активный протокол parser-service ↔ database:

| Поверхность | Почему это не активный DB-контракт |
|---|---|
| `DATABASE_URL` в compose/env | само наличие конфигурации не создает runtime DB-access |
| SQLAlchemy/Alembic dependencies | само наличие пакетов не создает runtime DB-access |
| Общий PostgreSQL container в compose | соседство по сети не означает живое использование read/write |
| Schema backend в той же database | parser-service не использует ее напрямую в inspected runtime |

## Операционная граница

```text
parser-service
  -> reads/writes config/sources.json
  -> emits sync/probe events over HTTP
  -> does not open a verified DB session in active runtime

backend
  -> receives parser-service output
  -> performs all durable writes to PostgreSQL
```

## Следствие контракта

Текущий протокол parser-service ↔ database документируется как отсутствующий намеренно, а не выводится по косвенным признакам.

Любая будущая прямая интеграция parser-service с database потребует нового first-class контракта, определяющего:

- ownership session,
- ownership таблиц,
- ownership миграций,
- transactional boundaries,
- semantics перезапуска и replay.

Ни одна из этих задач не является частью активного inspected runtime parser-service сегодня.
