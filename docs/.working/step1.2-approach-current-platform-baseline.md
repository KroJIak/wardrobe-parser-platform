# Подход: текущий базовый срез платформы

## Технологический стек
| Слой | Выбор | Почему это текущая реализация |
|-------|--------|--------------------------------------|
| Frontend | React + TypeScript + Vite + nginx | Текущий подмодуль `frontend` собирает `admin` и `site` из одной кодовой базы и раздает их через nginx. |
| Backend | FastAPI + SQLAlchemy + Pydantic | Текущий авторитетный API, auth, catalog, settings, dedup и логика showcase. |
| Parser Service | FastAPI + Python parsing stack + Node/Chromium browser runner | Текущее выполнение source execution, probe и оркестрации sync. |
| Database | PostgreSQL + Alembic | Текущее постоянное хранилище для curated/admin/runtime data. |
| Среда кэша и worker | Redis + backend worker process | Текущая поддержка кэширования изображений и pricing-поведения во время выполнения. |
| Развертывание | Docker Compose / Dokploy | Текущая локальная и hosted topology. |

## Реализуемость функций
| Функция | Текущая реализация | Сложность | Риски |
|---------|------------------------|-----------|-------|
| Загрузка данных из источников | adapters + strategies + sync orchestrator в parser-service | HIGH | разрастание strategies, тяжелый контейнер среды выполнения |
| Curated catalog API | маршруты products/categories/showcase в backend | HIGH | очень большие route files и плотная оркестрация |
| Административные операции | admin tabs frontend + shared provider + backend RBAC routes | HIGH | крупный shared state hub и рассеянные контракты |
| Публичная витрина | public catalog/showcase endpoints backend + lightweight site entrypoint | MEDIUM | публичный сайт во время выполнения пока сильно проще dormant source code |
| Pricing и settings | settings/pricing services backend + admin UI | HIGH | крупный service layer и множество межполейных зависимостей |

## Оценки
| Измерение | Балл (1-5) | Обоснование |
|-----------|-------------|-----------|
| Скорость разработки | 3 | Существующие модули ускоряют инкрементальные изменения, но связность замедляет безопасное расширение. |
| Масштабируемость | 3 | Отдельный parser-service помогает, но in-memory orchestration и большие route/service files мешают чистому scale-out. |
| Поддерживаемость | 2 | Cross-cutting state, большие файлы, зеркальные контракты и смешанное владение снижают ясность. |
| Соответствие команде | 4 | Стек построен на распространенных Python/React/Docker технологиях. |
| Стоимость | 4 | В основном self-hosted компоненты; тяжелый обязательный слой SaaS в коде не виден. |
| Гибкость | 3 | Модульные границы есть, но многие внутренние контракты ручные и хрупкие. |
| **Итого** | **19/30** | Подходит для documentation-as-built, но пока не идеален для долгосрочной скорости реализации. |

## Оценка стоимости
| Сервис | Стоимость в месяц | Примечания |
|---------|-------------|-------|
| PostgreSQL + Redis + app containers | зависит от инфраструктуры | self-hosted / зависит от среды выполнения |
| Dokploy hosting | зависит от инфраструктуры | deployment-platform, не принадлежащая коду |
| Доступ к external storefronts | прямой стоимости нет | целевые сайты, а не platform SaaS |
| **Итого** | **зависит от deployment** | текущий repo не кодирует фиксированную модель SaaS-стоимости |

## Риски
| Риск | Влияние | Вероятность | Смягчение |
|------|--------|-----------|------------|
| Расхождение контрактов между frontend/backend/service | HIGH | HIGH | canonical API/data-model documentation перед рефакторингом |
| Большие orchestration-files, смешивающие ответственности | HIGH | HIGH | задокументировать границы владения и позже разделить по доменам и слоям |
| Parser jobs, живущие только в процессе | MEDIUM | HIGH | точно задокументировать поведение и ограничения до redesign |
| Совместное/частичное владение source settings между backend и parser-service | HIGH | MEDIUM | явно зафиксировать владение в docs и плане будущего рефакторинга |

## Рекомендация
Единственный корректный подход для этой фазы — задокументировать текущий базовый срез платформы ровно так, как он реализован. Цель фазы — создать архитектурный источник истины без потери информации, по которому затем можно критиковать и проводить рефакторинг.
