# Админская аутентификация и runtime синхронизации

## Область действия
Этот файл покрывает storage admin RBAC, singleton-table admin UI, persisted state sync runtime и таблицу версий Alembic, которая отслеживает ownership схемы.

## Таблица: `admin_role`
Назначение: именованная роль RBAC со списком permissions в JSONB.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `name` | `VARCHAR(128)` | no | — | уникальное имя роли |
| `description` | `TEXT` | yes | `null` | optional description |
| `permissions` | `JSONB` | no | `[]` | список scopes permissions backend |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |

Ограничения и индексы:
- PK: `id`
- Unique: `name`
- Index: `idx_admin_role_name`

Примечание по происхождению:
- Создана в `0031_admin_rbac_users_roles`

## Таблица: `admin_user`
Назначение: credentials административного аккаунта и assignment роли.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `login` | `VARCHAR(128)` | no | — | уникальный admin login |
| `password_hash` | `VARCHAR(512)` | no | — | payload hash PBKDF2 |
| `is_active` | `BOOLEAN` | no | `true` | флаг soft disable |
| `is_superuser` | `BOOLEAN` | no | `false` | флаг superadmin, управляемый startup |
| `role_id` | `INTEGER` | yes | `null` | FK на `admin_role.id`, `ON DELETE SET NULL` |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |

Ограничения и индексы:
- PK: `id`
- Unique: `login`
- FK: `role_id -> admin_role.id (SET NULL)`
- Index: `idx_admin_user_login`

Сценарии доступа:
- Записывается account service backend и logic bootstrap на startup
- Никогда не читается frontend напрямую; только проецируется через APIs auth/account

## Таблица: `admin_ui_settings`
Назначение: singleton-row admin-facing настроек для merchandising UI и состояния scheduler.

Ожидание backend:
- Row `id = 1` seed'ится во время `0020_admin_ui_settings_split`

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `designers_min_products` | `INTEGER` | no | `1` | вынесено из pricing settings в `0020` |
| `designers_exclude_store_vendors` | `BOOLEAN` | no | `false` | вынесено из pricing settings в `0020` |
| `showcase_hero_image_asset_id` | `INTEGER` | yes | `null` | без FK-constraint |
| `showcase_carousel_image_asset_ids` | `JSON` | no | `[]` | без FK-constraint |
| `auto_sync_period_minutes` | `INTEGER` | no | `60` | добавлено в `0028` |
| `auto_sync_next_run_at` | `TIMESTAMPTZ` | yes | `null` | добавлено в `0032` |
| `auto_sync_last_started_at` | `TIMESTAMPTZ` | yes | `null` | добавлено в `0032` |
| `auto_sync_last_finished_at` | `TIMESTAMPTZ` | yes | `null` | добавлено в `0032` |
| `auto_sync_last_status` | `VARCHAR(32)` | yes | `null` | добавлено в `0032` |
| `auto_sync_last_error` | `TEXT` | yes | `null` | добавлено в `0032` |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp создания |

Ограничения и индексы:
- PK: `id`
- Index: `idx_admin_ui_settings_updated_at`
- Нет foreign key от columns изображений showcase к `image_asset`

## Таблица: `sync_applied_batch`
Назначение: ledger idempotency для применения batches parser-service.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `aggregate_job_id` | `VARCHAR(64)` | no | — | id aggregate job backend |
| `service_job_id` | `VARCHAR(64)` | no | — | id job parser-service |
| `batch_id` | `VARCHAR(255)` | no | — | id chunk parser batch/event |
| `source_key` | `VARCHAR(255)` | yes | `null` | optional identifier source |
| `created_at` | `TIMESTAMPTZ` | no | `now()` | timestamp вставки |

Ограничения:
- PK: `id`
- Unique: `uq_sync_applied_batch_service_job_batch (service_job_id, batch_id)`

Примечание по происхождению:
- Создана в `0023_sync_applied_batches`

## Таблица: `sync_job_runtime`
Назначение: persisted-view backend на aggregate sync job, который может охватывать несколько jobs или events parser-service.

| Колонка | Тип | NULL | По умолчанию | Примечания |
|---|---|---:|---|---|
| `id` | `INTEGER` | no | — | primary key |
| `aggregate_job_id` | `VARCHAR(64)` | no | — | уникальный id aggregate job backend |
| `service_job_id` | `VARCHAR(64)` | no | — | id текущей связанной job parser-service |
| `status` | `VARCHAR(32)` | no | — | строковый status job backend |
| `created_at` | `TIMESTAMPTZ` | no | — | timestamp, явно передаваемый приложением; без DB default |
| `started_at` | `TIMESTAMPTZ` | yes | `null` | старт runtime |
| `completed_at` | `TIMESTAMPTZ` | yes | `null` | завершение runtime |
| `total_sources` | `INTEGER` | no | `0` | общее число sources |
| `processed_sources` | `INTEGER` | no | `0` | число обработанных sources |
| `expected_db_upserts` | `INTEGER` | no | `0` | ожидаемое число persistence units |
| `db_upserts_done` | `INTEGER` | no | `0` | число завершенных persistence units |
| `failed_products` | `INTEGER` | no | `0` | число failed products |
| `current_source_name` | `VARCHAR(255)` | yes | `null` | label текущего source |
| `current_source_index` | `INTEGER` | no | `0` | cursor текущего source |
| `current_stage` | `VARCHAR(255)` | yes | `null` | label текущего stage |
| `products_success` | `INTEGER` | no | `0` | число успешных products |
| `products_error` | `INTEGER` | no | `0` | число products с ошибкой |
| `event_cursor` | `INTEGER` | no | `0` | consumed event offset |
| `can_cancel` | `BOOLEAN` | no | `true` | возможность отмены |
| `error_message` | `TEXT` | yes | `null` | текст последней ошибки |
| `updated_at` | `TIMESTAMPTZ` | no | `now()` | timestamp mutation |

Ограничения:
- PK: `id`
- Unique: `aggregate_job_id`

Примечание по происхождению:
- Создана в `0024_sync_job_runtime`

## Техническая таблица: `alembic_version_backend`
Назначение: таблица состояния Alembic для backend-owned schema migrations.

Observed contract:
- Одноколоночная таблица с primary key `version_num`
- Создается/управляется из `backend/alembic/env.py`
- Отличается от default naming Alembic, чтобы избежать неоднозначности с другими modules

## Операционные примечания
- Само auth-state не сохраняется как rows сессий; токены подписываются и проверяются в слое backend, а rate limiting делегирован Redis.
- `sync_job_runtime` и `sync_applied_batch` образуют единственный проверяемый долговечный журнал job'ов. Состояние runtime parser-service со своей стороны остается process-local и event-driven.
- `admin_ui_settings` является singleton конфигурации, а не таблицей user-scoped preferences.
