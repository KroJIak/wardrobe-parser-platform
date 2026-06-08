# Wardrobe Parser Platform — Мастер-план

## Что это за платформа

Wardrobe Parser Platform — это система для загрузки, нормализации и мерчандайзинга каталога модных товаров. Она объединяет публичную веб-поверхность, операторскую административную панель, backend API для оркестрации и отдельный рантайм парсера, который собирает товары из внешних витрин источников.

Корневой репозиторий выступает orchestration-workspace и связывает три Git submodule: `backend`, `frontend` и `service`. Система построена вокруг одной общей схемы PostgreSQL и одного авторитетного backend API. Сервис парсинга выполняет sync jobs, привязанные к конкретным источникам, backend курирует и обогащает итоговый каталог, а frontend публикует отдельные точки входа для `admin` и `site`.

## Домены системы

| Домен                                 | Директория               | Назначение                                                                                       | Технологический стек                                       | Файлов |
| ------------------------------------- | ------------------------ | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------- | ------ |
| Фронтенд                              | `frontend-design/`       | Браузерный рантайм для полного `admin`-SPA и отдельного минимального `site` entrypoint           | React, TypeScript, Vite, nginx                             | 11     |
| Бэкенд                                | `backend-design/`        | Авторитетный API, auth, orchestration, curation, public showcase                                 | FastAPI, SQLAlchemy, Pydantic, Redis                       | 10     |
| Сервис парсинга                       | `parser-service-design/` | Парсинг источников, проверочные потоки и sync-рантайм в памяти процесса                          | FastAPI, Python, Node, Chromium, Xvfb                      | 9      |
| База данных                           | `database-schema/`       | Общая постоянная schema и распределение ownership по группам таблиц                              | PostgreSQL, Alembic                                        | 5      |
| Инфраструктура                        | `infra-design/`          | Топология Compose, локальная сеть рантайма и операции развертывания                              | Docker Compose, Dokploy, nginx                             | 4      |
| Вспомогательные материалы репозитория | `repo-auxiliary/`        | Служебные скрипты, тестовые и лабораторные рабочие области, сохраненные отчеты и резервные копии | Python scripts, Compose sandboxes, JSON/Markdown artifacts | 3      |

## Слой API

Директория `api/` — это канонический источник истины для междоменных контрактов.
Документы доменов ссылаются на файлы из `api/`, а не переопределяют формы payload прямо внутри себя.

| Директория / файл | Связывает | Тип |
|------------------|-----------|-----|
| `api/00-SUMMARY.md` | все домены | индекс и матрица взаимодействий |
| `api/auth.md` | frontend ↔ backend | cookie session и RBAC |
| `api/protocols/frontend--backend.md` | frontend ↔ backend | REST |
| `api/protocols/backend--parser-service.md` | backend ↔ parser service | внутренний REST |
| `api/protocols/backend--database.md` | backend ↔ database | ORM / SQL |
| `api/protocols/parser-service--database.md` | parser service ↔ database | задокументированная неконтрактная / латентная зависимость |
| `api/data-models/*.md` | общие сущности | канонические формы полей |

## Схема взаимодействия доменов

```text
                 ┌──────────────────────┐
                 │   frontend-design    │
                 │ admin + site web UX  │
                 └──────────┬───────────┘
                            │
                    same-origin REST
                            │
                 ┌──────────▼───────────┐
                 │    backend-design    │
                 │ auth + catalog + ops │
                 └───────┬───────┬──────┘
                         │       │
              internal REST      │ SQLAlchemy / SQL
                         │       │
              ┌──────────▼───┐   ▼
              │ parser-      │ ┌─────────────────┐
              │ service-     │ │ database-schema │
              │ design       │ │ PostgreSQL      │
              └──────────────┘ └─────────────────┘
```

## Порядок проработки

### Волна 1

- `api/`: зафиксировать авторитетный слой контрактов и общие сущности.
- `database-schema/`: зафиксировать ownership постоянного состояния, write boundaries и legacy tables.

### Волна 2

- `parser-service-design/`: определить рантайм источников, registry источников и семантику sync events.
- `backend-design/`: определить authority системы над auth, catalog curation, settings и orchestration.

### Волна 3

- `frontend-design/`: определить поведение admin shell, site runtime, routing, auth UX и data access.

### Волна 4

- `infra-design/`: зафиксировать топологию развертывания и операционные правила.
- `repo-auxiliary/`: описать нерuntime-поверхности, которые живут в репозитории и нужны для эксплуатации и проверок.
- Выполнить перекрестную проверку всех доменных docs относительно contract layer перед планированием рефакторинга.

## Как читать этот набор документов

1. Начните с этого файла, чтобы увидеть полную карту системы.
2. Затем прочитайте `02-ARCHITECTURE.md`, чтобы понять архитектурные решения и форму развертывания.
3. Перед чтением доменной директории откройте `api/00-SUMMARY.md` и соответствующий файл из `api/protocols/`.
4. Внутри каждого домена всегда начинайте с `00-OVERVIEW.md`, затем идите по числовому порядку.
5. Для persistent state сопоставляйте доменные docs с соответствующим файлом из `database-schema/`.
6. Для нерuntime-поверхностей, которые находятся в репозитории, открывайте `repo-auxiliary/` после основных runtime-доменов.

## Индекс документов

| Директория | Файл | Назначение |
|-----------|------|------------|
| `(root)` | `00-MASTER-PLAN.md` | карта системы и порядок чтения |
| `(root)` | `01-HUMAN-CHECKLIST.md` | ручные предварительные условия и операционный чеклист |
| `(root)` | `02-ARCHITECTURE.md` | архитектурные решения и модель рантайма |
| `(root)` | `03-architecture-decision.md` | запись архитектурного решения |
| `api/` | `00-SUMMARY.md` | матрица взаимодействий и индекс API |
| `api/` | `auth.md` | сквозной auth contract |
| `api/data-models/` | `*.md` | канонические общие сущности и enums |
| `api/protocols/` | `*.md` | контракты между парами доменов |
| `database-schema/` | `00-overview.md` | карта схемы и ownership matrix |
| `database-schema/` | `01-parser-catalog-core.md` | parser sources, parser products, media, favorites |
| `database-schema/` | `02-categories-pricing-and-merchandising.md` | categories, pricing, weight, brand, showcase |
| `database-schema/` | `03-admin-auth-and-sync-runtime.md` | admin users/roles и таблицы sync-рантайма |
| `database-schema/` | `04-legacy-ingest-tables.md` | сохраненные legacy-таблицы продуктов и сайта |
| `frontend-design/` | `00-OVERVIEW.md` … `10-ui-styling-and-static-assets.md` | архитектура браузерной стороны |
| `backend-design/` | `00-OVERVIEW.md` … `09-deployment-and-operations.md` | авторитетный API и orchestration |
| `parser-service-design/` | `00-OVERVIEW.md` … `08-observability-reports-and-operational-limits.md` | архитектура рантайма парсера |
| `infra-design/` | `00-OVERVIEW.md` … `03-operations-and-secrets.md` | топология рантайма и правила hosting |
| `repo-auxiliary/` | `00-OVERVIEW.md` … `02-testing-labs-and-diagnostics.md` | служебные материалы, лаборатории, отчеты, резервные копии, инвентарь проверки |
