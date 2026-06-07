# Анализ PRD

## Проблема и пользователи
Wardrobe Parser Platform агрегирует данные о товарах из нескольких внешних storefront модной розницы, нормализует и курирует эти данные, а затем предоставляет их через операторскую админ-панель и публичный сайт-витрину. Основные пользователи — операторы платформы, которые управляют ingest-процессами, pricing, категоризацией, deduplication, настройками showcase и административным доступом, а также конечные пользователи, просматривающие публичный каталог.

## Основные функции
1. Многоисточниковый ingest из внешних storefront через выделенный parser service.
2. Реестр источников под управлением admin с enable/sync flags, видимостью атрибутов, supplier binding и валютным поведением.
3. Оркестрация sync-job с latest-job status, event streaming, cancel и фоновыми обновлениями через worker.
4. Управление product catalog с фильтрацией, ручным созданием, ручным редактированием, upload изображений и source probe/preview workflows.
5. Управление category tree с keywords, ручными привязками товаров, favorite/fallback semantics и snapshots количества по категориям.
6. Генерация dedup candidate, решения merge/reject/combine и история moderation с возможностью отката.
7. Конфигурация pricing с формулами, suppliers, shipping rate tiers, currency rates и оценкой example product.
8. Управление weight-rule плюс public weight-rules contract для parser.
9. Brand-mapping и merchandising controls, связанные с designers.
10. Управление showcase media для hero image и carousel assets.
11. Аутентификация admin, RBAC, управление ролями и пользователями, cookie-based sessions.
12. Public catalog/showcase API для категорий, product detail и showcase media.
13. Settings export/import/reset для миграции операционного состояния.

## Пользовательские потоки
1. Администратор входит через cookie-based auth и открывает `/control/:tab`.
2. Администратор просматривает источники, запускает sync-job, наблюдает runtime progress и при необходимости отменяет запуск.
3. Backend запускает и мониторит parser-service jobs, а затем ingest-ит emitted product batches в curated catalog.
4. Администратор проверяет products, categories, weights, pricing и dedup decisions, после чего вносит ручные правки.
5. Администратор настраивает изображения showcase и public merchandising settings.
6. Public site потребляет backend public catalog/showcase endpoints и рендерит storefront.

## Нефункциональные требования
- Same-origin web-среда выполнения для взаимодействия frontend с backend в Docker.
- Внутренние service-to-service HTTP contracts между backend и parser-service.
- Постоянное PostgreSQL-хранилище для curated/admin/runtime state.
- Поддержка кэша и worker через Redis для runtime-задач backend.
- Парсинг источников должен выдерживать гетерогенные storefront strategies, включая browser automation.
- Авторизация admin должна быть permission-scoped, а не только роль-ориентированной.
- Операционная модель деплоя: Docker Compose локально и Dokploy/Traefik в hosted-среде выполнения.

## Домены системы
| Домен | Назначение | Сложность | Упомянутые технологии |
|--------|---------|-----------|------------------------|
| Frontend | Админ-панель и публичные web-entrypoints в одном Vite-проекте | сложно | React, TypeScript, Vite, nginx, Tailwind |
| Backend | Авторитетный API, auth/RBAC, catalog curation, pricing, jobs, showcase | сложно | FastAPI, SQLAlchemy, Pydantic, PostgreSQL, Redis |
| Parser Service | Движок выполнения источников для discovery/fetch/probe/sync workflows | сложно | FastAPI, Python, Node, Chromium, Xvfb |
| Database | Общее постоянное состояние для curated catalog, admin auth, pricing, runtime metadata, legacy ingest tables | сложно | PostgreSQL, Alembic |
| Инфраструктура выполнения | Контейнерная топология, reverse proxying, worker/runtime окружение, маршрутизация Dokploy | средне | Docker Compose, nginx, Dokploy, Traefik |

## Междоменные взаимодействия
| Откуда -> Куда | Тип канала | Что передается | Примечания |
|-----------|-------------|-------------|-------|
| Frontend -> Backend | Same-origin REST по `/api/v1` | auth, products, sources, jobs, categories, settings, showcase, dedup | cookie-based sessions |
| Backend -> Parser Service | Внутренний REST | source registry mirror, sync jobs, probe jobs, event polling, cancel | строится из `SERVICE_BASE_URL` |
| Parser Service -> Backend | Внутренний REST | получение public weight-rule contract | `BACKEND_BASE_URL` |
| Backend -> Database | ORM/SQL | curated catalog, admin auth, pricing, categories, job runtime, settings | управляется Alembic |
| Parser Service -> Database | в текущем проверенном runtime flow не реализовано | env/deps есть, но активный DB layer не обнаружен | вместо этого используется файловый source registry |
| Backend -> Redis | internal cache/worker runtime | image cache и background rate data | зависимость на стороне backend |

## Точки решений
| # | Решение | Варианты | Текущее ограничение |
|---|----------|---------|--------------------|
| 1 | Frontend topology | single SPA / dual apps in one repo / separate repos | текущий код использует dual apps в одном repo |
| 2 | Backend-service split | monolith / separate sync service | текущий код уже использует отдельный parser service |
| 3 | Data ownership | shared DB / isolated DBs | сейчас backend владеет общей PostgreSQL schema; parser-service в основном file-backed |
| 4 | Admin auth | header token / cookie session | текущий frontend/backend используют cookie session с refresh |
| 5 | Персистентность source config | DB / file / remote config service | текущий parser-service использует `service/config/sources.json` |
| 6 | Интеграция public site | SSR app / SPA / static site | текущий runtime предоставляет простой site entrypoint с backend-backed public APIs |

## SaaS и сторонние зависимости
| Сервис | Категория | Для чего используется | Требует регистрации | Free Tier | Нужны credential | Используется доменами | Сложность настройки |
|---------|----------|---------|----------------------|-----------|-------------------|-------------------|-----------------|
| External storefronts | Другое | Цели для product discovery и extraction | нет | N/A | нет platform-owned секретов | Parser Service | просто |
| Bybit P2P API/data source | Другое | FX/pricing rate enrichment в backend pricing runtime | явный публичный HTTP-flow в коде не предполагается | частично | в env не видно явного platform key | Backend | просто |
| Dokploy | Облако/хостинг | Hosted deployment и target для routing по доменам | да | частично | platform account/project config | Инфраструктура выполнения | средне |

## Кандидатные подходы
### Подход 1: текущий базовый срез платформы
- Выбор: dual-entry frontend repo, FastAPI backend, отдельный FastAPI parser-service, shared PostgreSQL, backend-owned admin/public API, file-backed parser source config, Docker-based deployment.
- Обоснование: запрошенная документация должна описывать существующую систему ровно такой, какой она реализована, не подменяя архитектуру на этапе документации.
- Подходит для: создания авторитетной спецификации текущего состояния перед рефакторингом и cleanup.

## Вывод фазы 1
Для этой задачи существует только одна жизнеспособная цель документации: текущий базовый срез платформы. Альтернативные архитектуры уместны только на этапе будущего рефакторинга и намеренно находятся вне области этого документационного прохода.
