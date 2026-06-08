# Backend / API / Database Coverage Audit

## Что было не так
- `docs/api` и `docs/database-schema` все еще описывали legacy `shipping_rules` как живую часть pricing-модели, хотя текущий backend уже удалил это поле из API, runtime и БД.
- `docs/backend-design/07-pricing-weight-and-settings.md` сохранял старый narrative про fallback SSR и зависимость manual source от заранее существующего supplier bootstrap.
- `docs/backend-design/04-sync-and-source-orchestration.md` описывал manual source только как уже материализованную строку `parser_source`, тогда как текущий код умеет возвращать виртуальный manual source и материализует его лишь при назначении supplier.
- `docs/database-schema/00-overview.md` и `docs/backend-design/03-data-layer-and-schema-ownership.md` отставали по линии миграций и не доходили до `0037_drop_legacy_shipping_rules.py`.

## Что исправлено
- Обновлены `docs/api/00-SUMMARY.md`, `docs/api/protocols/frontend--backend.md`, `docs/api/data-models/pricing-settings.md`, `docs/api/data-models/pricing-supplier.md`, `docs/api/data-models/source.md`.
- Обновлены `docs/backend-design/04-sync-and-source-orchestration.md`, `docs/backend-design/07-pricing-weight-and-settings.md`, `docs/backend-design/03-data-layer-and-schema-ownership.md`.
- Обновлены `docs/database-schema/00-overview.md` и `docs/database-schema/02-categories-pricing-and-merchandising.md`.
- Зафиксировано, что source of truth для SSR теперь только `parser_supplier_shipping_rate` / `suppliers[].rates`.
- Зафиксировано, что backend генерирует supplier key по схеме `supplier-{id}`.
- Зафиксировано, что manual source в `/sources` может быть виртуальным до первого назначения supplier.

## Residual risk
- В `backend-design/05-product-catalog-and-public-showcase.md` manual-source narrative остается на более высоком уровне и не раскрывает виртуальную/materialized двухступенчатую модель так подробно, как `04-sync-and-source-orchestration.md`.
- Документация описывает текущую reality `GET /api/v1/products` как hybrid/compatibility endpoint, но сам кодовый proxy-слой остается архитектурно спорным и может быть перепроектирован позже.
- Аудит сосредоточен на truthfulness current-state, а не на нормализации самой backend-архитектуры.
