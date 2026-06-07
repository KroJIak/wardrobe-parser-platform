# Повторный аудит покрытия документации

## Область охвата

Этот re-audit сравнивает текущую codebase с `docs/`, исключая `docs/internal/`.
Он также повторно проверяет findings, ранее зафиксированные в:

- `docs/.working/coverage-audit-frontend.md`
- `docs/.working/coverage-audit-backend.md`
- `docs/.working/coverage-audit-parser-service.md`
- `docs/.working/coverage-audit-cross-docs.md`

Цель — проверить, описывает ли обновленная документация теперь реальную поверхность проекта, а не только deployed runtime baseline.

## 1. Закрытые findings

### Наблюдения по frontend из предыдущего аудита: закрыты

Ранее отмеченные gaps frontend теперь явно покрыты в `docs/`.

Закрытые пункты:
- navigation admin к `/product/:id?from=admin` теперь задокументирована вместе с ее фактическим mounted-runtime consequence на admin host:
  - `docs/frontend-design/02-app-entrypoints-and-routing.md`
- `useLiveDataBootstrap()` теперь документирует guard `lastRouteKindRef` и факт, что bootstrap выполняется только на переходах route-kind, а не на каждом изменении pathname:
  - `docs/frontend-design/05-data-access-and-live-context.md`
- `useLiveJobPolling()` теперь документирует более широкий набор terminal refresh-trigger, а не только простой переход running-to-terminal:
  - `docs/frontend-design/05-data-access-and-live-context.md`
- запуск sync теперь документирует preflight `GET /jobs/latest` и явную обработку конфликта `409`:
  - `docs/frontend-design/05-data-access-and-live-context.md`
  - `docs/api/protocols/frontend--backend.md`
- docs dormant catalog теперь включают module-scope caches, abort behavior запросов и защиту от stale-response:
  - `docs/frontend-design/09-public-site-runtime.md`
- лимит upload в nginx теперь задокументирован как `client_max_body_size 100m`:
  - `docs/frontend-design/01-project-setup.md`
- кэширование permissions edit showcase теперь документирует module-scope negative caching behavior:
  - `docs/frontend-design/04-auth-and-session-flow.md`

Вердикт по frontend:
- предыдущие существенные gaps закрыты
- текущие frontend docs точно описывают split runtime `admin` / `site`

### Наблюдения по backend из предыдущего аудита: закрыты

Ранее отмеченные mismatch контрактов и persistence backend теперь задокументированы существенно точнее.

Закрытые пункты:
- `PATCH /api/v1/products/{product_id}` больше не описывается как fully recomputed product read; docs теперь фиксируют lightweight acknowledgement-style payload:
  - `docs/backend-design/05-product-catalog-and-public-showcase.md`
  - `docs/api/protocols/frontend--backend.md`
- image JSON columns в `parser_product` теперь документируются с их текущим runtime representation в виде URL/token, а не fictive asset-id:
  - `docs/database-schema/01-parser-catalog-core.md`
  - `docs/api/data-models/parser-product.md`
- settings import/reset теперь документирует:
  - full-only semantics reset
  - отсутствие reset source-default в parser-service
  - live host matching для patch source parser-service
  - minimum `auto_sync_period_minutes = 60`
  - refs:
    - `docs/backend-design/07-pricing-weight-and-settings.md`
    - `docs/api/data-models/settings-transfer.md`
- docs по категориям теперь включают protected branch `Дизайнеры`, правила regeneration и ограничения mutation system-branch:
  - `docs/backend-design/06-categories-dedup-and-merchandising.md`
- docs по sync-job теперь покрывают:
  - startup rewrite для interrupted jobs `queued` / `in_progress`
  - опциональные `sources` и `candidate_urls_by_source`
  - более богатые aggregate orchestration notes
  - refs:
    - `docs/backend-design/04-sync-and-source-orchestration.md`
    - `docs/api/data-models/sync-job.md`
    - `docs/api/protocols/backend--parser-service.md`
- docs по dedup теперь описывают active runtime knobs и тот факт, что current candidate generation фактически остается available-only независимо от stored flag `dedup_only_available_products`:
  - `docs/backend-design/06-categories-dedup-and-merchandising.md`
  - `docs/backend-design/07-pricing-weight-and-settings.md`
  - `docs/api/data-models/pricing-settings.md`

Вердикт по backend:
- прежние truth-gaps закрыты на уровне документации
- текущие backend docs описывают реальную форму контракта и оговорки, а не более чистую целевую форму

### Наблюдения по parser-service из предыдущего аудита: закрыты

Docs parser-service теперь фиксируют ранее пропущенные runtime-details.

Закрытые пункты:
- docs по probe-cancel теперь явно различают ordinary sync cancel и probe cancel и отмечают, что probe cancel сейчас не реализует ту же явную ветку `404` для unknown job:
  - `docs/parser-service-design/07-backend-contracts-and-weight-enrichment.md`
- правила forwarding для `product_batch` теперь описывают:
  - требование `source_product_url`
  - требование непустого `variants[]`
  - расширенные normalized item fields, такие как `canonical_url`, `external_id`, `unavailable_reason`, `buyer_total_price` и `buyer_service_fee`
  - refs:
    - `docs/parser-service-design/07-backend-contracts-and-weight-enrichment.md`
    - `docs/api/data-models/sync-event.md`
    - `docs/api/protocols/backend--parser-service.md`
- документация по payload событий теперь включает более богатую форму payload для `source_started`, `source_progress`, progress requeue и terminal events:
  - `docs/parser-service-design/03-sync-api-and-orchestrator-runtime.md`
  - `docs/api/data-models/sync-event.md`
  - `docs/api/protocols/backend--parser-service.md`
- docs по browser-runner теперь совпадают с текущими scenario ids и нюансами runtime/config:
  - `default-shopify-sitemap`
  - `dolcevitahub-shopify-sitemap`
  - опциональный `max_sitemaps`
  - опциональный `shopify_currency.country_code`
  - `includeLocaleSitemaps` задокументирован как присутствующий в config, но не активно потребляемый проверенной Python strategy
  - refs:
    - `docs/parser-service-design/06-browser-runner-and-automation.md`
    - `docs/parser-service-design/02-source-registry-and-configuration-model.md`

Вердикт по parser-service:
- прежние concrete runtime mismatches закрыты
- текущие docs описывают service таким, каким он реализован, включая менее полированные части

### Наблюдения по кросс-документному repo-adjacent coverage: по сути закрыты

Предыдущий cross-doc audit говорил, что runtime coverage полное, но repo-adjacent surfaces отсутствуют.
Теперь это закрыто следующими документами:

- `docs/repo-auxiliary/00-OVERVIEW.md`
- `docs/repo-auxiliary/01-maintenance-scripts-and-backups.md`
- `docs/repo-auxiliary/02-testing-labs-and-diagnostics.md`
- top-level inclusion в `docs/00-MASTER-PLAN.md`

Эти docs теперь покрывают ранее пропущенные repo-adjacent surfaces:
- `backend/scripts/reset_category_tree.py`
- `testing/*` как реальный lab/probe workspace
- `service/reports/*` как checked-in diagnostic/report artifacts
- `backups/db/*` как checked-in backup artifacts
- verification/test inventory как first-class repository concern

## 2. Оставшиеся gaps, если они есть

Новой крупной недокументированной подсистемы, deployable unit, cross-service contract или owner persistence в текущей codebase не найдено.

Оставшиеся gaps несущественны и относятся скорее к granular detail, а не к отсутствующей архитектуре:

1. `repo-auxiliary/` точно описывает repo-adjacent surfaces по классам и назначению, но не пытается делать полный file-by-file inventory каждого checked-in artifact в:
   - `service/reports/runs/*`
   - `testing/*`
   - directories с image fixtures под `testing/*_images`
   Для documentation уровня architecture и project-surface этого достаточно, но это не буквальный каталог каждого artifact file.

2. Некоторые исторические module-local files вне `docs/` все еще могут расходиться с canonical docs set, например старые README или notes. Это не снижает качество покрытия `docs/`, но означает, что `docs/` следует считать авторитетным слоем поверх разрозненных локальных заметок.

3. Репозиторный шум вроде `.obsidian/` не документируется, и это правильно, потому что это workspace tooling, а не project runtime или repository-domain behavior.

Итоговая оценка remaining gaps:
- существенных пропусков runtime или product-surface не осталось
- при желании можно только расширять не-критичную глубину inventory/detail

## 3. Полное покрытие проекта против покрытия только runtime

Docs больше не ограничиваются только deployed runtime.

Текущее состояние:
- покрытие runtime: полное
- покрытие repo-adjacent engineering/operational surface: присутствует
- top-level reading map включает и runtime domains, и repository auxiliary domains

Что теперь покрыто сверх runtime:
- maintenance mutation surface в `backend/scripts/`
- testing/lab workspaces в `testing/`
- checked-in parser reports в `service/reports/`
- checked-in database dump artifacts в `backups/db/`
- verification inventory как часть фактической структуры repository

Следовательно:
- `docs/` теперь покрывает полную поверхность проекта в практическом инженерном смысле
- они больше не ограничены только тем, “что запускается в Docker”

Единственное, чем они не пытаются быть, — это forensic file-by-file inventory каждого generated report, fixture или ad hoc artifact.

## 4. Финальная уверенность

Финальная уверенность: высокая.

Обоснование:
- предыдущие findings по frontend, backend, parser-service и cross-doc были перепроверены относительно обновленных docs и текущего кода
- скрытых крупных code surface вне задокументированной domain map не найдено
- недавно добавленный раздел `repo-auxiliary/` закрыл единственный ранее существенный boundary gap между “runtime docs” и “docs всего проекта”

Формулировка уверенности:
- высокая уверенность, что `docs/` теперь описывает реальную структуру проекта, контракты, persistence boundaries, runtime behavior и repo-adjacent engineering surfaces без крупных пропусков
- средняя уверенность только в исчерпывающем artifact-by-artifact enumeration, потому что docs намеренно суммируют большие наборы вроде run reports и lab fixtures вместо индексации каждого отдельного файла
