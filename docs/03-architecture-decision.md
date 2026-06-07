# Запись архитектурного решения

## Контекст

Платформа должна одновременно поддерживать три ключевых класса задач:

1. browser-facing административные операции для каталога и merchandising workflow
2. browser-facing public showcase и выдачу каталога
3. source-specific parsing и синхронизацию внешних catalog data

При этом она должна сохранять одну авторитетную persistent schema, одну auth boundary
и одну видимую для операторов control surface.

## Архитектурная форма

Утвержденная архитектура — это модульная платформа, состоящая из:

- одного backend API как авторитетной business boundary
- одного специализированного runtime парсера для sync execution
- одной общей PostgreSQL schema, которой владеют backend migrations
- одного frontend module с двумя deployable entrypoint: `site` и `admin`

## Рассмотренные альтернативы

### Встроить логику парсера в backend

Отклонено для baseline-архитектуры, потому что parser execution требует существенно более тяжелого runtime:
browser automation, Node tooling, Chromium и source-specific strategies.

### Разделить site и admin по разным репозиториям

Отложено.
Текущая архитектура сохраняет одну web codebase с двумя deployable output, потому что обе точки входа разделяют
stack, deployment cadence и существенную часть state/UI infrastructure.

### Считать parser service равноправным владельцем database

Отклонено для текущего baseline.
Хотя parser service получает `DATABASE_URL` и содержит SQL-related dependencies, inspected runtime
не показывает active first-class DB contract, сопоставимого с ownership backend.

## Решение

Использовать текущий baseline платформы как authoritative architecture:

- `frontend-site` и `frontend-admin` — отдельные web deployment из одного frontend module
- `backend` остается единственной public/admin API boundary
- `service` остается специализированным parser и probe runtime
- `backend` остается владельцем migrations и curated database state
- `api/` остается contract layer для всех следующих implementation и refactor работ

## Обоснование

Такая форма соответствует реальным зонам ответственности рантайма и удерживает domain boundaries согласованными
с deployment units. Она также дает documentation system, на которую можно опираться при рефакторинге,
не выдумывая target architecture, которой текущая система еще не соответствует.

## Последствия

### Плюсы

- четкая системная authority для auth, curation и public read models
- явная документация для file-backed parser state в отличие от DB-backed curated state
- отдельные deploy target для site и admin без размножения репозиториев
- стабильный contract layer для последующей очистки кода

### Компромиссы

- frontend все еще содержит shared/admin-heavy logic, не полностью изолированную от site source tree
- parser-service runtime остается process-local для job state
- backend остается плотным orchestration center для нескольких business areas

## Правило пересмотра

Любое будущее архитектурное изменение, которое меняет:

- ownership migrations
- repository boundaries frontend
- persistence strategy parser-service
- auth transport или permission model

должно одновременно обновлять этот ADR и соответствующие документы `api/`, domain docs и schema docs.
