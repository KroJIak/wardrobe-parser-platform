# Вспомогательные материалы репозитория: тесты, лаборатории и диагностика

## Область применения

- Охватывает: verification assets, exploratory workspaces, parser reports и diagnostic-материалы вне runtime, закоммиченные в repo.
- НЕ охватывает: поведение deployed request flow.

## Инвентарь тестов

### Тесты backend

Наблюдаемые примеры:

- `backend/tests/test_auth_flow.py`

### Тесты parser-service

Наблюдаемые примеры:

- `service/tests/test_sync_orchestrator_service.py`
- `service/tests/test_source_run_service.py`
- adapter-focused tests в `service/tests/test_*adapter.py`

Эти tests — часть поверхности проекта, хотя они и не описаны в runtime architecture docs.

## Тестовые и лабораторные рабочие области

Верхнеуровневое дерево `testing/` — это реальная инженерная рабочая область вокруг платформы.

Наблюдаемые поверхности:

- `testing/browser-parser/docker-compose.yml`
- `testing/dolcevitahub-lab/docker-compose.yml`
- `testing/manual_probe_goat_product.py`
- `testing/probe_sources_audit.py`
- `testing/parser/*`

Эти assets не являются shipped product, но являются активными project tools для probing, auditing и experimentation.

## Диагностические отчеты парсера

Репозиторий включает сохраненные parser diagnostic artifacts в `service/reports/`, включая:

- reality checks
- fallback checks
- field-coverage checks
- product probes
- per-run reports в `service/reports/runs/*`

Эти artifacts — свидетельство реальной parser investigation и validation work.

## Текущая интерпретация

- `service/reports/*` — не runtime persistence layer
- `testing/*` — не часть deployed platform topology
- оба класса artifacts остаются first-class repository surfaces, важными при документировании всего проекта, а не только deployed baseline
