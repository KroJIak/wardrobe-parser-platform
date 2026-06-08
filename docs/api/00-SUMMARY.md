# Сводка API-слоя

## Область действия
Эта директория является каноническим слоем контрактов для текущего runtime платформы:

- `frontend` получает JSON от backend по same-origin REST.
- `backend` владеет публичными и административными HTTP-контрактами и хранением данных в PostgreSQL.
- `parser-service` владеет файловой конфигурацией источников и выполнением sync/probe в памяти процесса.
- `database` хранит curated/admin/runtime-состояние, которым владеет `backend`.

В состав директории входят:
- канонические общие модели данных в `data-models/`
- сквозное поведение auth и RBAC в `auth.md`
- контракты взаимодействия между парами доменов в `protocols/`

## Матрица взаимодействия доменов
| Откуда \\ Куда | `frontend` | `backend` | `parser-service` | `database` |
|---|---|---|---|---|
| `frontend` | - | REST | ✗ | ✗ |
| `backend` | REST | - | внутренний REST | SQL/ORM |
| `parser-service` | ✗ | внутренний REST | - | нет активного runtime-контракта первого класса |
| `database` | ✗ | SQL/ORM | только латентная зависимость | - |

## Канонические модели данных
| Сущность | Файл | Основные источники | Основные потребители |
|---|---|---|---|
| Административная учетная запись и роль | `data-models/admin-account.md` | backend, database | frontend |
| Административная сессия | `data-models/admin-session.md` | backend | frontend |
| Источник | `data-models/source.md` | backend, parser-service, database | frontend |
| Parser product | `data-models/parser-product.md` | backend, database | frontend |
| Product preview и manual draft | `data-models/product-preview.md` | backend, parser-service | frontend |
| Категория | `data-models/category.md` | backend, database | frontend |
| Dedup candidate и decision | `data-models/dedup.md` | backend, database | frontend |
| Настройки pricing | `data-models/pricing-settings.md` | backend, database | frontend |
| Поставщик pricing | `data-models/pricing-supplier.md` | backend, database | frontend |
| Правило веса | `data-models/weight-rule.md` | backend, parser-service, database | frontend |
| Состояние showcase | `data-models/showcase-state.md` | backend, database | frontend |
| Sync job | `data-models/sync-job.md` | backend, parser-service, database | frontend |
| Sync event | `data-models/sync-event.md` | parser-service | backend |
| Brand mapping | `data-models/brand-mapping.md` | backend, database | frontend |
| Перенос настроек | `data-models/settings-transfer.md` | backend | frontend |
| Общие enums и state machines | `data-models/enums.md` | backend, parser-service | frontend, database |

## Документы протоколов
| Протокол | Файл | Канал | Сводка |
|---|---|---|---|
| `frontend` ↔ `backend` | `protocols/frontend--backend.md` | same-origin REST | admin auth, административные операции, showcase/catalog, гибридные product-routes |
| `backend` ↔ `parser-service` | `protocols/backend--parser-service.md` | внутренний REST | зеркалирование реестра источников, sync jobs, probe jobs, event stream, получение weight-rules |
| `backend` ↔ `database` | `protocols/backend--database.md` | SQLAlchemy / SQL | владение репозиториями, записи в таблицы, authority миграций |
| `parser-service` ↔ `database` | `protocols/parser-service--database.md` | документированный non-contract | явная фиксация того, что активный inspected runtime не использует БД |

## Поверхность Auth
Сквозное поведение auth и RBAC определено в [auth.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/auth.md:1).

## Правила представления
| Слой | Naming | Примечания |
|---|---|---|
| `frontend` JSON / TypeScript | в основном поля в `snake_case`, повторяющие backend JSON | текущие frontend-типы сохраняют соглашение именования backend, а не переводят его в camelCase |
| `backend` Pydantic / Python | `snake_case` | прямой источник REST-ответов |
| `parser-service` Python | `snake_case` | payload request/response и dataclasses |
| `database` SQLAlchemy / PostgreSQL | `snake_case` | схема и миграции, которыми владеет backend |

## Текущие характеристики контракта
- Backend является единственным авторитетным источником публичных и административных REST-контрактов.
- Контракты parser-service узкие и ориентированы на sync: registry источников, orchestration jobs, probe jobs, event stream.
- Frontend содержит рукописные TypeScript-зеркала payload backend; generated client отсутствует.
- Public-style showcase/catalog/product endpoints backend сейчас активно потребляются admin showcase runtime.
- `site` как отдельная сборка существует, но текущий mounted runtime ограничен одной страницей `be monki` и не использует catalog/showcase API.
