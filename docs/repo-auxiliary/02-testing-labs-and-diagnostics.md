# Вспомогательные материалы репозитория: тесты, лаборатории и диагностика

## Область применения

- Охватывает: verification assets, exploratory workspaces и diagnostic-материалы вне runtime, закоммиченные в repo.
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
- `testing/run_source_dryrun_with_logs.py`
- `testing/run_goat_adapter_dryrun.py`

Эти assets не являются shipped product, но являются активными project tools для probing, auditing и experimentation.

### Текущие группы материалов внутри `testing/`

| Группа | Примеры | Что это такое |
|---|---|---|
| Browser sandboxes | `testing/browser-parser/*`, `testing/dolcevitahub-lab/*` | изолированные compose/worker-стенды для browser-based parsing |
| Manual product probes | `manual_probe_goat_product.py`, `manual_probe_vinted_product.py`, `manual_probe_store_backlash_product.py`, `manual_probe_intl_protocol_index.py` | ручные проверки отдельных storefront/product flows |
| Parser tooling | `testing/parser/shopify_audit_runner.py`, `shopify_export_products.py`, `crawlee_shopify_benchmark.mjs`, `advanced-sitemap-parser/*` | утилиты и мини-проекты для исследования стратегий и качества парсинга |
| Audit outputs | `probe_sources_report.json`, `probe_sources_report.md`, `*_probe.json` | сохраненные результаты разовых проверок |
| Research notes | `testing/parser/*.md`, `testing/direct-image-flow-removal-plan.md`, `testing/image-flow-migration-plan.md` | инженерные заметки и планы рядом с экспериментами |

## Текущая интерпретация

- `testing/*` — не часть deployed platform topology
- это developer-side инженерная рабочая область, а не часть deployed platform topology
