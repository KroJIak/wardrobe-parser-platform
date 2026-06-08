# Аудит кросс-документного покрытия

## 1. Сводка покрытия

### Вывод

Покрытие **фактического runtime платформы** практически полное.

Я не нашел недокументированный крупный deployable unit, крупный shared API contract, крупную runtime dependency, core operational flow или first-class legacy runtime surface внутри текущей topology `frontend` / `backend` / `service` / Compose.

Текущий набор docs уже покрывает:

- deployable/runtime units:
  - `frontend-site`
  - `frontend-admin`
  - `backend`
  - `backend-worker`
  - `service`
  - `postgres`
  - `redis`
  - `backend-db-init`
  - `service-db-init`
  - `db-admin` только для override
- cross-domain contracts:
  - `frontend <-> backend`
  - `backend <-> parser-service`
  - `backend <-> database`
  - `parser-service <-> database` как явный non-contract
- владение базой и legacy schema:
  - parser catalog tables
  - pricing/categories/showcase/admin runtime tables
  - сохраненные legacy `sites/products/product_images`
- основные runtime constraints:
  - same-origin proxying через nginx
  - file-backed `service/config/sources.json`
  - process-local parser job state
  - backend-owned migrations
  - dormant site code против активного placeholder site
  - backend proxy/compatibility product routes
  - unauthenticated showcase mutation routes
  - игнорируемые `IMAGE_*` env vars в backend config

### Статус покрытия по областям

| Область | Статус | Примечания |
|---|---|---|
| Верхнеуровневая архитектура и карта чтения | Complete | `docs/00-MASTER-PLAN.md`, `docs/02-ARCHITECTURE.md`, `docs/03-architecture-decision.md` |
| API contracts и shared models | Complete | `docs/api/*` и `docs/api/protocols/*` |
| Backend runtime и operations | Complete | `docs/backend-design/*` |
| Frontend runtime, active admin, dormant site | Complete | `docs/frontend-design/*` |
| Parser-service runtime, adapters, browser runner, sync API | Complete | `docs/parser-service-design/*` |
| Database schema и legacy tables | Complete | `docs/database-schema/*` |
| Local/hosted infra и secrets | Complete | `docs/infra-design/*` |
| Repo-adjacent operational/testing workspace | Partial | см. findings ниже |

## 2. Наблюдения по убыванию важности

### Medium: repo-adjacent maintenance и diagnostic surfaces не представлены, поэтому покрытие пока нельзя считать “полным для всего repo”

Docs хорошо покрывают production/runtime platform, но пока не описывают несколько repo-resident surfaces, которые операционно значимы, даже если не входят в нормальную container topology:

- backend maintenance script:
  - `backend/scripts/reset_category_tree.py:1-220`
- parser diagnostic artifacts:
- top-level exploratory/testing workspace:
  - `testing/browser-parser/docker-compose.yml`
  - `testing/dolcevitahub-lab/docker-compose.yml`
  - `testing/manual_probe_goat_product.py`
  - `testing/probe_sources_audit.py`
  - `testing/parser/*`
- checked-in backup artifacts:
  - `backups/db/wardrobe_pre_reset_20260509-180343.dump`
  - `backups/db/wardrobe_pre_reset_20260509-180355.dump`

Почему это важно:

- `backend/scripts/reset_category_tree.py` — это не просто заметка и не dead file. Он открывает DB session, удаляет не-system categories, пересоздает tree roots и seed-ит keywords, то есть это реальная maintenance/mutation surface.
- `testing/` содержит дополнительные compose files, dry-run probes, parser audits и lab artifacts, которые реально используются для исследования и валидации repo.
- `backups/db/` — это не runtime-code, но meaningful repository assets с операционным контекстом.

Точные doc refs, показывающие текущую границу:

- `docs/00-MASTER-PLAN.md:13-21` определяет только пять system domains.
- `docs/00-MASTER-PLAN.md:91-111` индексирует весь docs set и не включает repo-auxiliary/testing/backup materials.
- `docs/backend-design/09-deployment-and-operations.md:8-22` покрывает только deployed topology.
- `docs/infra-design/03-operations-and-secrets.md:47-55` описывает backup priorities, но не checked-in artifacts `backups/db/*.dump`, уже присутствующие в repo.

Нужны ли правки docs?

- **Да**, если цель — буквально “весь repo, без пропуска meaningful surface”.
- **Нет**, если цель — только “baseline shipped runtime architecture”.

Рекомендуемый scope изменений docs:

- добавить небольшой appendix или каталог repo-auxiliaries, который явно опишет:
  - maintenance scripts
  - testing/lab workspaces
  - checked-in backups и их статус/назначение

### Low: surface автоматической проверки присутствует только неявно, а не как first-class repo concern

В repo есть реальная test surface, но текущие docs скорее упоминают test dependencies, чем описывают реальные verification assets:

- backend:
  - `backend/tests/test_auth_flow.py:1-70`
- service:
  - `service/tests/test_sync_orchestrator_service.py:1-89`
  - `service/tests/test_source_run_service.py`
  - adapter-specific tests в `service/tests/test_*adapter.py`

Сейчас docs касаются этого только косвенно:

- `docs/backend-design/01-project-setup.md:34-40` перечисляет `pytest` и `httpx` как installed dependencies.
- `docs/parser-service-design/01-project-setup-and-runtime-dependencies.md:64` упоминает `pytest` как dependency, но в наборе docs нет отдельного verification/test-inventory document.

Это не провал runtime-coverage, но это все же documentation gap, если стандарт — “проект ровно таким, какой он есть в repo”.

Нужны ли правки docs?

- **Опционально, но желательно** для полного покрытия repo.
- Достаточно короткого appendix вроде `verification` или `repo-quality`.

### Low: один legacy module README все еще рекламирует compatibility docs alias, который не совпадает с реальным code path

Это не gap нового docs set; новые docs корректны. Но во время аудита был найден repo-local mismatch, который стоит зафиксировать:

- code:
  - `backend/app/core/app_factory.py:179-218`
  - фактический route для markdown download — `/api/docs/public.md`
- module README:
  - `backend/README.md:8-11`
  - все еще рекламирует `/api/docs/showcase.md`
- new docs:
  - `docs/backend-design/01-project-setup.md:51-60`
  - корректно документируют `/api/docs/public.md`

Нужны ли правки docs?

- **Нет** для основного набора docs.
- Позже стоит очистить устаревший module README, но это не снижает качество покрытия `docs/`.

## 3. Итоговая оценка

### Что точно покрыто хорошо

- Развертываемая система задокументирована достаточно подробно, чтобы служить baseline для рефакторинга.
- Contract layer присутствует и согласован со структурой проверенного кода.
- Текущие messy, но реальные границы задокументированы честно:
  - гибридный `/api/v1/products`
  - остатки backend proxy
  - dormant site implementation
  - in-memory orchestration parser-service
  - владение миграциями backend
  - legacy tables, которые все еще сохранены

### Что еще остается вне документированной границы

Оставшаяся uncovered area — это в основном **repo-adjacent operational workspace**, а не основной runtime:

- ad hoc maintenance scripts
- parser reality-check reports
- manual probe labs
- checked-in DB dumps
- явный test inventory

## 4. Остаточные области с низкой уверенностью

Это не блокирующие gaps, но именно здесь в “100% repo coverage” остается наибольшая неопределенность:

- Я проверил существование и назначение `testing/*` и `backups/db/*`, но не исполнял эти scripts и не десериализовал dump files.
- Я делал выборочную проверку ключевых runtime entrypoints/configs/routers/services, а не перечитывал line-by-line каждую реализацию adapter.
- Основной docs set выглядит внутренне согласованным, но repo-local supporting README могут все еще содержать небольшие historical drift, как mismatch alias `showcase.md`, отмеченный выше.

## 5. Финальный вердикт

Если критерий приемки такой:

- **“Полностью ли `docs/` описывает фактический deployed platform baseline?”**
  - **Да.**

- **“Описывает ли `docs/` уже весь repository, включая maintenance scripts, lab tooling, backups и verification assets?”**
  - **Пока нет.**

Недостающая часть — это не скрытая production subsystem. Это repo-adjacent engineering workspace вокруг платформы.
