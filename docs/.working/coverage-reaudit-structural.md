# Повторный структурный аудит и re-audit покрытия `docs/`

## Область охвата и стандарт аудита

Этот re-audit проверяет, остается ли какая-либо **крупная поверхность кода, конфигурации, runtime или repository** вне документированной границы `docs/`.

В рамках аудита явно перепроверены:

- top-level structure репозитория
- структура `docs/` после последних правок
- runtime entrypoints для `backend`, `frontend` и `service`
- `docker-compose.yml`, `docker-compose.override.yml` и `.env.example`
- `testing/`
- `backups/db/`
- `backend/scripts/`

Это аудит **структурного покрытия**, а не line-by-line review семантических контрактов. Главный вопрос такой:

> Покрывает ли `docs/` теперь весь проект на уровне major deployable units, major config/runtime surfaces и major repository-resident engineering/operational surfaces?

## Проверенные структурные поверхности

### 1. Основные runtime modules

Подтверждено наличие в repo и представление в `docs/`:

- `backend/` -> `docs/backend-design/`
- `frontend/` -> `docs/frontend-design/`
- `service/` -> `docs/parser-service-design/`
- shared persistence -> `docs/database-schema/`
- topology container/runtime -> `docs/infra-design/`
- cross-boundary contracts -> `docs/api/`

Проверенные подтверждения:

- `backend/app/main.py`
- `backend/app/core/app_factory.py`
- `frontend/src/admin/admin-app.tsx`
- `frontend/src/site/site-app.tsx`
- `service/app/main.py`
- `docker-compose.yml`

### 2. Верхнеуровневая runtime и deploy topology

Подтверждено наличие в repo и представление в `docs/`:

- `postgres`
- `redis`
- `backend-db-init`
- `service-db-init`
- `backend`
- `backend-worker`
- `service`
- `frontend-site`
- `frontend-admin`
- `db-admin` только из override

Проверенные подтверждения:

- `docker-compose.yml`
- `docker-compose.override.yml`
- `.env.example`
- `docs/infra-design/01-local-compose.md`
- `docs/infra-design/02-hosted-dokploy-and-networking.md`
- `docs/infra-design/03-operations-and-secrets.md`

### 3. Repo-adjacent engineering и operational surfaces

Подтверждено наличие в repo и представление в `docs/`:

- `backend/scripts/reset_category_tree.py`
- checked-in DB dumps в `backups/db/`
- top-level engineering workspace в `testing/`

Проверенные подтверждения:

- `backend/scripts/reset_category_tree.py`
- `backups/db/*.dump`
- `testing/browser-parser/*`
- `testing/dolcevitahub-lab/*`
- `testing/manual_probe_*.py`
- `testing/parser/*`
- `docs/repo-auxiliary/00-OVERVIEW.md`
- `docs/repo-auxiliary/01-maintenance-scripts-and-backups.md`
- `docs/repo-auxiliary/02-testing-labs-and-diagnostics.md`

## Наблюдения по убыванию важности

### Low: verification и lab surfaces документированы как inventory groups, а не как исчерпывающие per-file catalogs

Новый раздел `repo-auxiliary/` закрыл предыдущий structural gap вокруг repository-resident engineering surfaces. Теперь он явно покрывает:

- maintenance scripts
- checked-in backups
- testing/lab workspaces

Менее детализированной остается **granularity**, а не само наличие покрытия:

- backend tests представлены единственным существующим файлом `backend/tests/test_auth_flow.py`
- parser-service tests представлены как семейство с примерами
- `testing/parser/*` задокументирован как workspace, а не как file-by-file map

Оценка:

- это **уже не** крупная missing surface
- это ограничение глубины и детализации внутри уже задокументированной области

### Low: некоторые repo-local support files остаются вне основного narrative docs, но они не являются major project surfaces

Примеры:

- top-level и module-local `README.md`
- `.obsidian/`
- локальные examples, такие как `frontend/.env.local.example`

Оценка:

- это не скрытые deployable units, не скрытые runtime dependencies и не скрытые operational subsystems
- их отсутствие в основном documentation set **не** означает, что у проекта есть недокументированная major surface

### Info: оставшийся documentation risk — это точность и precision, а не structural omission

Ранее module-specific audits уже находили несколько mismatch или упрощений на уровне поведения в:

- frontend runtime details
- backend response/storage semantics
- parser-service event payloads

Эти findings важны для безопасности будущего рефакторинга, но это другой вопрос, чем тот, который проверяется здесь.

Для этого re-audit важна следующая точка:

- сами major surfaces теперь представлены в `docs/`
- основная оставшаяся работа — это sharpening exactness внутри существующих docs, а не поиск новых отсутствующих project areas

## Вердикт покрытия по поверхностям

| Surface | Статус структурного покрытия | Примечания |
|---|---|---|
| Верхнеуровневая архитектурная карта | Complete | `docs/00-MASTER-PLAN.md`, `docs/02-ARCHITECTURE.md` |
| Runtime compose topology | Complete | `docs/infra-design/*` |
| Backend runtime и operations | Complete | `docs/backend-design/*` |
| Frontend runtime и split entrypoints | Complete | `docs/frontend-design/*` |
| Parser service runtime | Complete | `docs/parser-service-design/*` |
| Shared DB/schema ownership | Complete | `docs/database-schema/*` |
| Cross-domain contracts | Complete | `docs/api/*` |
| Maintenance scripts | Complete | `docs/repo-auxiliary/01-maintenance-scripts-and-backups.md` |
| Checked-in DB backups | Complete | `docs/repo-auxiliary/01-maintenance-scripts-and-backups.md` |
| Testing и lab workspace | Complete на структурном уровне | покрыт как grouped engineering workspace, а не per-file catalog |

## Финальный ответ

На уровне **строгого структурного покрытия** ответ такой:

**Да — весь проект теперь задокументирован в `docs/` в терминах major code, config, runtime и repository-resident operational/engineering surfaces.**

Я **не** нашел оставшуюся недокументированную крупную subsystem, deployable unit, major config surface или major repo-resident operational workspace после последних правок.

То, что еще остается, относится к другому классу работы:

- подтянуть accuracy существующих docs на уровне поведения
- при желании повысить детализацию inventory для test/lab areas

Поэтому корректный финальный вердикт такой:

- **Структурное покрытие всего проекта:** **Да**
- **Behavior-level/document precision уже идеальны везде:** **Нет**
