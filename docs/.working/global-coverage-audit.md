# Global Coverage Audit

Дата аудита: 2026-06-08

## Scope

Аудит выполнен в режиме read-only по:

- top-level docs: `docs/00-MASTER-PLAN.md`, `01-HUMAN-CHECKLIST.md`, `02-ARCHITECTURE.md`, `03-architecture-decision.md`
- `docs/frontend-design/`
- `docs/backend-design/`
- `docs/api/`
- `docs/database-schema/`
- `docs/parser-service-design/`
- `docs/infra-design/`
- `docs/repo-auxiliary/`

Исключено:

- `docs/internal/**`

Сопоставление сделано против текущего кода и runtime-конфигурации в:

- `frontend/`
- `backend/`
- `service/`
- `docker-compose.yml`
- `docker-compose.override.yml`
- Dockerfiles и nginx/Vite runtime

## Executive Summary

Baseline docs все еще полезны как архитектурная карта доменов и runtime-топологии, но уже не являются полностью правдивым implementation baseline.

Главные причины:

1. `frontend-design` и связанный `api/frontend--backend` narrative отстали от последних frontend-изменений от 2026-06-06 и 2026-06-08:
   - split `site/admin` на уровне build/deploy задокументирован;
   - но фактический runtime теперь асимметричен: `frontend-site` рендерит только landing page, а public-style showcase/product/category routes живут в `AdminApp`.
2. `SSR/pricing cleanup` задокументирован неполно.
   - Интерпретирую `SSR` здесь как supplier shipping rate / cleanup legacy `shipping_rules`, потому что именно это подтверждают последние commits и migration `0037_drop_legacy_shipping_rules.py`.
   - В docs все еще остались stale-описания `shipping_rules` как живого поля/колонки.
3. В schema/backend docs остался drift по миграционной линии: текущая inspected revision chain уже доходит до `0037`, а часть docs все еще фиксирует `0036`.

Итог:

- Архитектурный baseline: в основном правдив.
- Runtime/detail baseline: частично устарел.
- Для безопасного использования как source of truth нужна ревизия минимум `frontend-design`, `api/` и pricing/schema docs.

## Current Ground Truth Snapshot

### Runtime topology

Подтверждено кодом и Compose:

- `frontend-site` и `frontend-admin` собираются из одного `frontend/` через `FRONTEND_APP` в `frontend/Dockerfile`.
- `frontend-site` и `frontend-admin` оба proxy `/api` на `backend` через `frontend/nginx/nginx.conf`.
- `backend-db-init` выполняет `alembic upgrade head`.
- `service-db-init` действительно no-op.
- `backend-worker` выполняет Bybit refresh + auto-sync scheduling.
- `service` не показывает активного DB runtime path первого класса, несмотря на наличие DB-зависимостей в `requirements.txt`.

### Frontend runtime reality

Подтверждено текущим кодом:

- `frontend/apps/admin/main.tsx` монтирует `AdminApp`.
- `frontend/apps/site/main.tsx` монтирует `SiteApp`.
- `SiteApp` сейчас рендерит `SiteHomePage`, то есть очень маленький landing, но не placeholder shell из старого описания.
- `AdminApp` теперь держит не только `/login` и `/control/:tab`, но и public-style routes:
  - `/`
  - `/catalog`
  - `/catalog/:slug`
  - `/category/:slug`
  - `/product/:id`
- Эти routes рендерятся через `AdminShowcaseLayout`, `ShowcaseHomePage`, `ShowcaseCategoryPage`, `ShowcaseProductPage`.

Следствие:

- build/deploy split `site/admin` реален;
- ownership UI-поведения split-нут не полностью;
- current showcase/catalog runtime живет главным образом внутри admin app, а не внутри site app.

### Pricing reality

Подтверждено текущим backend/frontend:

- 2026-06-07 frontend commit `c00e74a`: удален `shipping_rules` из frontend types.
- 2026-06-07 backend commit `e607571`: удалены legacy `shipping_rules` из модели, схем и pricing service.
- Есть новая migration `backend/alembic/versions/0037_drop_legacy_shipping_rules.py`.
- Текущий `ParserPricingSettings` больше не содержит `shipping_rules`.

## Coverage Matrix

| Area | Coverage verdict | Notes |
|---|---|---|
| Top-level docs | `Partial / mostly current` | Архитектурно верны, но не подсвечивают последний frontend drift и schema drift `0037`. |
| `frontend-design/` | `Stale in key runtime sections` | Самая заметная зона расхождений. |
| `backend-design/` | `Mostly current with minor drift` | Основные boundaries верны; есть drift по revision count. |
| `api/` | `Partial` | Auth/межсервисные контракты в целом живы, но frontend-runtime narrative и pricing model drift устарели. |
| `database-schema/` | `Stale for pricing lineage` | `shipping_rules` и revision line отстают от current schema. |
| `parser-service-design/` | `Mostly current` | Хорошо совпадает с кодом; мелкие operational детали не исчерпывающие, но явного слома baseline не найдено. |
| `infra-design/` | `Current` | Compose/runtime/networking согласуются с кодом. |
| `repo-auxiliary/` | `Mostly current, inventory not exhaustive` | Описывает реальные поверхности, но не покрывает весь фактический инвентарь файлов. |

## Detailed Findings

### 1. Top-level docs

Что совпадает:

- `00-MASTER-PLAN.md` и `02-ARCHITECTURE.md` корректно описывают домены, dual frontend containers, backend authority, parser-service split и общий runtime Compose.
- `01-HUMAN-CHECKLIST.md` согласуется с env/runtime и persistent volumes.
- `03-architecture-decision.md` все еще правдив на уровне high-level решения: один frontend module, два deploy targets.

Что недоописано или спорно:

- Top-level docs не проговаривают текущую асимметрию split-а:
  - `frontend-site` сейчас фактически landing-only;
  - showcase/category/product routes обслуживает `frontend-admin`.
- Top-level docs не фиксируют, что inspected migration line уже дошла до `0037`, а не `0036`.

Оценка:

- как карта системы: правдивы;
- как точное описание текущего frontend/runtime baseline: недостаточны.

### 2. `frontend-design/`

Сильные стороны:

- Общее разделение на `apps/admin` и `apps/site`, Vite modes и Docker build split задокументировано и соответствует коду.
- `06`, `07`, `08` по admin shell, categories, pricing, weight и settings в целом остаются полезными.

Ключевые устаревания:

1. `00-OVERVIEW.md`
   - все еще утверждает, что `site` "рендерит только страницу-заглушку";
   - ссылается на `docs/.working/frontend-analysis.md` и `docs/.working/step2.2-domain-internals.md`, то есть опирается на рабочие артефакты, а не только на baseline docs/code;
   - утверждает, что styling в основном единый через `src/styles.css`, хотя у `site` теперь есть отдельный `src/site/site.css`.
2. `01-project-setup.md`
   - частично устарел в части стилей: уже не только один общий `src/styles.css`.
3. `02-app-entrypoints-and-routing.md`
   - наиболее устаревший файл в директории;
   - ошибочно говорит, что `apps/site/main.tsx` импортирует общий `styles.css` и что `SiteApp` рендерит placeholder shell;
   - ошибочно утверждает, что `/product/:id?from=admin` на admin host не обслуживается и падает в wildcard redirect;
   - это уже не так: `AdminApp` реально держит `product/category/catalog` showcase routes.
4. `03-shared-types-and-transformers.md`
   - все еще ссылается на `src/site/catalog-helpers.ts`, `catalog-page.tsx`, `product-page.tsx`;
   - после frontend commit `c77f3b1` эти поверхности перемещены в `src/admin/showcase-*`.
5. `04-auth-and-session-flow.md`
   - directionally верен, но narrative про "текущую заглушку SiteApp и спящие site-страницы" уже устарел.
6. `09-public-site-runtime.md`
   - больше не соответствует дереву исходников;
   - описывает deleted/moved файлы (`src/site/layout.tsx`, `catalog-page.tsx`, `product-page.tsx`, `category-page.tsx`);
   - current `src/site/` теперь минимален и не содержит прежний dormant catalog/product stack.
7. `10-ui-styling-and-static-assets.md`
   - устарел в части styling architecture:
   - описывает global CSS как основной слой для обоих приложений;
   - current code уже имеет отдельный `src/site/site.css`.

Внутренняя несогласованность frontend docs:

- `07-admin-catalog-moderation-and-categories.md` уже исходит из навигации на `/product/:id?from=admin`;
- `02-app-entrypoints-and-routing.md` все еще утверждает, что такой переход не обслуживается.

Оценка:

- директория требует ревизии;
- именно она сейчас сильнее всего мешает считать docs baseline правдивым.

### 3. `backend-design/`

Что совпадает:

- domain boundaries backend, router map, worker presence, public OpenAPI filtering и ownership схемы описаны правдиво;
- `01-project-setup.md`, `09-deployment-and-operations.md` хорошо совпадают с `backend/app/core/app_factory.py`, `backend/app/core/config.py` и Compose;
- замечание о том, что часть env vars в Compose уже игнорируется backend settings, подтверждено кодом;
- warning о mixed router/service transaction boundaries соответствует current code.

Что устарело или недоописано:

1. `03-data-layer-and-schema-ownership.md`
   - все еще фиксирует `36` revisions и линию до `0036_relax_legacy_image_asset_not_null.py`;
   - current repo уже содержит `0037_drop_legacy_shipping_rules.py`.
2. В backend docs почти не отражен последний pricing cleanup от 2026-06-07 как отдельный drift-событие.

Оценка:

- в целом директория правдива;
- нужен небольшой schema/pricing refresh.

### 4. `api/`

Что совпадает:

- `auth.md` хорошо совпадает с `backend/app/api/v1/auth.py` и `frontend/src/shared/admin-auth.ts`;
- `backend--parser-service.md` и parser-related models выглядят согласованными с service runtime;
- naming conventions и общая матрица доменов в целом корректны.

Что устарело:

1. `00-SUMMARY.md`
   - все еще говорит о richer dormant site flows в `frontend/src/site` и placeholder runtime;
   - после `c77f3b1` эта картина уже неверна: showcase flows переехали под `src/admin/showcase-*`.
2. `protocols/frontend--backend.md`
   - stale narrative про current `site` как placeholder и про dormant `src/site/catalog-page.tsx`;
   - current public-style UI flows теперь живут в admin runtime, а не в `src/site/*`.
3. `data-models/pricing-settings.md`
   - содержит уже удаленное поле `shipping_rules`;
   - mapping в database-колонку для `shipping_rules` больше не соответствует модели и migration line.

Что спорно:

- `frontend--backend` по endpoint inventory в основном полезен, но его runtime commentary теперь частично вводит в заблуждение, потому что frontend ownership этих endpoint-ов сместился.

Оценка:

- как contract layer для auth/backend-parser остается полезным;
- как source of truth для frontend runtime и pricing model уже частично устарел.

### 5. `database-schema/`

Что совпадает:

- ownership backend над миграциями и активной схемой описан правильно;
- `admin_ui_settings`, `sync_job_runtime`, `sync_applied_batch`, legacy table notes и image asset mixed-era commentary выглядят актуально.

Ключевые устаревания:

1. `00-overview.md`
   - все еще указывает inspected revision line до `0036`;
   - current line уже включает `0037_drop_legacy_shipping_rules.py`.
2. `02-categories-pricing-and-merchandising.md`
   - все еще документирует колонку `parser_pricing_settings.shipping_rules`;
   - в current model и current migration line эта колонка уже удалена.

Оценка:

- pricing/schema baseline в этой директории сейчас не полностью правдив.

### 6. `parser-service-design/`

Что совпадает:

- `00-OVERVIEW.md`, `01`, `02`, `03`, `07`, `08` хорошо совпадают с current service code;
- файловый source registry, no-op `service-db-init`, in-memory orchestrators, weight-rules pull из backend и `product_batch` semantics описаны убедительно и подтверждаются кодом;
- count/shape `sources.json` в docs совпадает с current file.

Что недоописано:

- последние service hardening changes от 2026-06-08 (`18e74b5`, retry logic в `ShopifyHttpClient`) не вынесены явно как отдельное operational изменение;
- это скорее gap детализации, чем нарушение baseline truthfulness.

Оценка:

- одна из самых правдивых директорий в наборе.

### 7. `infra-design/`

Что совпадает:

- Compose topology, startup order, `backend-db-init` / `service-db-init`, port exposure, nginx proxy и dual frontend containers совпадают с runtime;
- hosted Dokploy/networking assumptions согласуются с текущими compose/docker файлами.

Что недоописано:

- директория почти не проговаривает frontend runtime asymmetry после split-а; но для infra это не критично.

Оценка:

- baseline правдив.

### 8. `repo-auxiliary/`

Что совпадает:

- `backend/scripts/reset_category_tree.py` реально существует и действительно является mutation surface;
- `backups/db/*.dump` реально присутствуют;
- `testing/` действительно служит lab/diagnostic workspace, а не runtime.

Что недоописано:

- инвентарь тестов и diagnostics приведен как примеры и не охватывает всю текущую фактическую поверхность:
  - backend tests уже включают как минимум `test_auth_flow.py` и `test_pricing_service_shipping.py`;
  - в `testing/` есть дополнительные планы/JSON probes/manual scripts, не перечисленные в docs;

Оценка:

- директория правдива, но обзорно-неполна.

## Latest Changes Coverage

### A. Split `site/admin`

Подтвержденные изменения:

- 2026-06-06, frontend commit `7a6a773`: multi-app support с `apps/admin` и `apps/site`.
- 2026-06-08, frontend commit `c77f3b1`: showcase pages и product management moved into admin runtime (`src/admin/showcase-*`), plus `SiteHomePage`.

Покрытие в docs:

- покрыто на high-level:
  - `00-MASTER-PLAN.md`
  - `02-ARCHITECTURE.md`
  - `03-architecture-decision.md`
  - `infra-design/*`
- покрыто неполно или уже неверно на detailed runtime level:
  - `frontend-design/00-OVERVIEW.md`
  - `frontend-design/02-app-entrypoints-and-routing.md`
  - `frontend-design/03-shared-types-and-transformers.md`
  - `frontend-design/09-public-site-runtime.md`
  - `frontend-design/10-ui-styling-and-static-assets.md`
  - `api/00-SUMMARY.md`
  - `api/protocols/frontend--backend.md`

Verdict по split:

- `split site/admin` как build/deploy decision покрыт;
- `split site/admin` как текущая runtime-реальность покрыт недостаточно и местами уже неверно.

### B. `SSR/pricing cleanup`

Интерпретация:

- Считаю, что здесь имеется в виду cleanup вокруг supplier shipping rates / legacy `shipping_rules`, а не server-side rendering.
- Причина: текущие последние changes по pricing прямо подтверждаются frontend/backend commits от 2026-06-07 и migration `0037`.
- Дополнительно: в текущем frontend stack нет SSR runtime; он остается Vite SPA + nginx.

Подтвержденные изменения:

- 2026-06-07, frontend commit `c00e74a`: removed unused `shipping_rules` from frontend types.
- 2026-06-07, backend commit `e607571`: removed legacy `shipping_rules` from pricing model/service/schema; added migration `0037_drop_legacy_shipping_rules.py`.

Покрытие в docs:

- не покрыто адекватно;
- stale следы cleanup остались в:
  - `docs/api/data-models/pricing-settings.md`
  - `docs/database-schema/02-categories-pricing-and-merchandising.md`
  - косвенно в migration-line notes, которые все еще заканчиваются на `0036`.

Verdict по pricing cleanup:

- покрытие недостаточное;
- baseline по pricing schema/model сейчас нельзя считать полностью правдивым.

## Areas That Are Still Underdescribed

Даже там, где docs не выглядят явно сломанными, остаются зоны слабого покрытия:

1. Реальная асимметрия frontend ownership:
   - `frontend-site` почти пустой;
   - `frontend-admin` несет showcase/category/product routes;
   - эта operational reality нигде не зафиксирована достаточно ясно как текущий baseline.
2. Последние pricing/schema drift events:
   - docs не подчеркивают, что cleanup `shipping_rules` уже завершен и закреплен миграцией.
3. Repo-level diagnostic/test inventory:
   - `repo-auxiliary` верен, но слишком обзорен для полного repo audit baseline.
4. Использование `.working` references внутри baseline docs:
   - как минимум `frontend-design/00-OVERVIEW.md` опирается на рабочие артефакты;
   - это делает baseline менее самодостаточным.

## Areas That Look Disputable

1. Формулировка "site runtime only placeholder" в нескольких docs уже спорна.
   - Да, site app маленький.
   - Но public-style showcase runtime больше не просто dormant: он жив в admin app.
2. Описание styling architecture как единого global CSS для обоих приложений спорно после появления `src/site/site.css`.
3. Narrative про dormant `src/site/catalog-page.tsx` и `product-page.tsx` уже просто не совпадает с деревом исходников.

## Final Verdict

Короткий verdict:

- `docs baseline` нельзя считать полностью правдивым implementation baseline.
- Его можно считать directionally truthful только на уровне доменной карты, Compose/runtime topology и parser-service/backend high-level architecture.
- Для практической работы как source of truth сначала нужны обновления минимум в:
  - `frontend-design/`
  - `api/00-SUMMARY.md`
  - `api/protocols/frontend--backend.md`
  - `api/data-models/pricing-settings.md`
  - `database-schema/00-overview.md`
  - `database-schema/02-categories-pricing-and-merchandising.md`
  - `backend-design/03-data-layer-and-schema-ownership.md`
