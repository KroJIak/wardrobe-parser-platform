# Обзор схемы базы данных

## Назначение
`database-schema/` описывает схему PostgreSQL, которой владеет модуль backend. Backend является единственным inspected domain, который активно мигрирует и сохраняет application state. `parser-service` разделяет тот же `DATABASE_URL` во время runtime, но inspected code service не публикует активный database-протокол первого класса; его долговременное state по-прежнему file-backed в `config/sources.json`.

## Контур владения миграциями
- Инструмент миграций: Alembic в `backend/alembic`
- Таблица версий: `alembic_version_backend`
- Текущая inspected-линия revisions: от `0001_backend_init` до `0036_relax_legacy_image_asset_not_null`
- Ownership в compose: `backend-db-init` выполняет `alembic upgrade head`; `service-db-init` является no-op

## Группы схемы
| Файл | Область |
|---|---|
| `01-parser-catalog-core.md` | parser sources, curated parser products, dedup records, brand mappings, image assets |
| `02-categories-pricing-and-merchandising.md` | дерево категорий, category indexes, singleton pricing, supplier tariffs, weight rules |
| `03-admin-auth-and-sync-runtime.md` | admin RBAC, singleton admin UI, persisted tables sync runtime, таблица версий Alembic |
| `04-legacy-ingest-tables.md` | pre-parser ingest tables, все еще присутствующие в metadata и миграциях |

## Сводка доступа по доменам
| Домен | Метод доступа | Текущая роль |
|---|---|---|
| `backend-design` | SQLAlchemy ORM + Alembic | авторитетный reader/writer для всех активных таблиц |
| `parser-service-design` | в inspected runtime не подтвержден активный DB-access | разделяет только connection settings |
| `frontend-design` | прямого DB-access нет | потребляет только backend REST |

## Карта связей
```text
parser_supplier
    └─< parser_source
           └─< parser_product
                  ├─< parser_product_origin_variant
                  ├─1 parser_favorite_product
                  ├─< parser_category_manual_product >─ parser_category
                  ├─< parser_product_category_match >─ parser_category
                  └─< parser_dedup_decision (left/right/merged_into all point back to parser_product)

parser_category
    ├─ self parent/children
    ├─< parser_category_keyword
    └─1 parser_category_count_snapshot

parser_category_index_state
    └─ техническая singleton-style таблица маркеров rebuild без foreign keys

parser_weight_rule
    └─< parser_weight_keyword

admin_role
    └─< admin_user

sync_job_runtime
sync_applied_batch

admin_ui_settings
    └─ хранит ids изображений showcase в JSON / scalar fields без foreign keys

image_asset

sites
    └─< products
           └─< product_images
```

## Матрица владения записью
| Группа таблиц | Основной writer | Примечания |
|---|---|---|
| Parser catalog core | services sync/orchestration backend | наполняется событиями parser-service, сохраняется backend |
| Категории и matches | services категорий backend | и ручные assignments, и вычисляемые indexes принадлежат backend |
| Pricing и suppliers | services pricing/settings backend | backend seed'ит singleton defaults и rows tariffs SSR |
| Weight rules | service weight-rule backend | parser-service потребляет public contract backend вместо прямого доступа к tables |
| Admin auth | services auth/account backend | прямых external writers нет |
| Sync runtime | orchestration jobs backend | отслеживает aggregate-view backend поверх jobs parser-service |
| Legacy ingest tables | активный writer в inspected current flows не подтвержден | сохраненная surface схемы из ранней product-phase |

## Линия миграций по областям
| Область | Ключевые revisions | Результат |
|---|---|---|
| Legacy ingest | `0001`, `0003`, `0004`, `0005`, `0006` | `sites`, `products`, `product_images` плюс size-поля и удаление `raw_data` |
| Bootstrap parser core | `0002` | создает base tables supplier, source, parser product, category, pricing, weight, dedup, image asset |
| Индексация категорий | `0007`, `0008`, `0009`, `0010` | keyword scope, ручные assignments, match snapshots, нормализация slug data |
| Pricing и merchandising | `0011`, `0012`, `0013`, `0014`, `0021`, `0022` | thresholds designers, ranges supplier tariff, seeded canonical tariffs, nullable `jpy_to_usd_rate` |
| Контроли curation продукта | `0016`, `0017`, `0018`, `0019`, `0025`, `0026`, `0027`, `0029`, `0030`, `0033`, `0034` | auto-hide flags, text/media overrides, brand mapping, source visibility flags, sync telemetry, origin variants, dedup snapshots, description visibility override |
| Admin/runtime | `0020`, `0023`, `0024`, `0028`, `0031`, `0032` | split singleton admin UI, tables sync idempotency/runtime, tables RBAC, поля runtime auto-sync |
| Выравнивание image asset | `0035`, `0036` | добавлены runtime-columns, при этом legacy image-columns остаются и частично nullable |

## Модель безопасности
- В inspected migrations не найдено row-level security policies.
- Авторизация обеспечивается routers/services backend, а не database policies.
- Несколько tables используют soft-delete columns (`deleted_at` или `is_deleted`) вместо физического удаления.
- Payload columns JSON и JSONB являются доверенными application-контрактами; схема не валидирует их внутреннюю shape.

## Текущие структурные примечания
- `parser_product.url` создается как unique в `0002_parser_core_init`; текущая ORM-model больше не объявляет эту uniqueness явно, но ни одна более поздняя migration ее не удаляет.
- `image_asset` является таблицей смешанных эпох. Код runtime использует `source_url`, `storage_mode`, `stored_path`, `created_at` и `deleted_at`, тогда как более старые колонки вроде `kind` и `storage_rel_path` все еще остаются в таблице после `0035` и `0036`.
- `admin_ui_settings` и `parser_pricing_settings` являются singleton-style таблицами. Backend ожидает seeded row `id = 1`.
- `service` все еще содержит dependencies SQLAlchemy и Alembic, но ни один inspected runtime path не показывает прямое сохранение в эти tables.
