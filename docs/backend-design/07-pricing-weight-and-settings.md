# Архитектура Backend: Pricing, Вес и Настройки

## Область
- Покрывает: pricing settings, suppliers, настройки admin UI, правила веса, публичный weight contract для parser, flows переноса настроек.
- Не покрывает: низкоуровневый deployment compose/runtime или детали реализации parser-service.
- Зависит от: `03-data-layer-and-schema-ownership.md`.

## Роутер настроек
`app/api/v1/settings.py` - это основная HTTP-поверхность для operational configuration.

Endpoints:

| Endpoint | Назначение | Permission |
|---|---|---|
| `GET /settings/pricing` | текущие pricing settings | `control.pricing.read` |
| `PATCH /settings/pricing` | обновить pricing settings | `control.pricing.edit` |
| `GET /settings/admin-ui` | admin UI + showcase settings | `control.settings.read` |
| `PATCH /settings/admin-ui` | обновить admin UI + showcase settings | `control.settings.edit` |
| `POST/PATCH/DELETE /settings/pricing/suppliers...` | CRUD supplier/tariff | `control.pricing.edit` |
| `GET /settings/weight-rules` | текущие weight rules | `control.weight.read` |
| `GET /settings/weight-rules/parser-contract` | parser contract в admin-view | `control.weight.read` |
| `GET /settings/weight-rules/missing-products` | products без resolved weight | `control.weight.read` |
| `POST/PATCH/DELETE /settings/weight-rules...` | CRUD weight rule | `control.weight.edit` |
| `POST/DELETE /settings/weight-rules/{rule_id}/keywords...` | CRUD weight keyword | `control.weight.edit` |
| `GET /settings/export` | полный payload export settings | `control.settings.read` |
| `POST /settings/import` | import payload settings | `control.settings.edit` |
| `POST /settings/reset` | полный reset domains settings, принадлежащих backend | `control.settings.edit` |

## Сервис pricing
`PricingSettingsService` - один из самых больших service modules в backend и выступает как:

- слой CRUD pricing settings;
- слой CRUD suppliers/tariffs;
- service admin UI settings;
- calculator price, используемый projections product/catalog;
- surface integration external FX/market data.

Это шире, чем узкий "settings service".

### Обязанности pricing, используемые в product flows
Когда products возвращаются admin или public callers, backend использует pricing settings для вычисления:

- нормализации source price
- final price
- компонентов buyout/service surcharge
- promo и supplier adjustments
- результатов currency conversion и rounding

Поэтому pricing settings - это часть read model, а не только часть admin configuration.

## Владение suppliers и tariffs
Suppliers хранятся в DB backend и используются:

- responses pricing settings;
- назначением supplier source profile в `sources.py`;
- вычислением final price во время projection product;
- bootstrap manual source, для которого требуется хотя бы одна строка supplier.

Если suppliers отсутствуют, создание synthetic manual source завершается ошибкой.

## Правила веса
Поведение weight централизовано в `WeightRuleService`.

Обязанности:

- при необходимости seed default rules;
- CRUD rules и keywords;
- listing products, у которых отсутствует derived weight;
- публикация parser-facing contract payload;
- участие в pricing product через разрешение effective weight.

### Генерация parser contract
Оба endpoints:

- `GET /settings/weight-rules/parser-contract`
- `GET /public/parser-contract/weight-rules`

строят одну и ту же форму payload:

- normalized list rules `{weight_grams, keywords[]}`
- deterministic revision hash из sorted rules

Public endpoint parser-contract не требует authentication и существует специально для потребления parser-service.

## Настройки admin UI
Настройки admin UI сохраняются persistently и не ограничиваются cosmetic toggles.

Наблюдаемое использование включает:

- id asset image showcase hero
- ids asset images showcase carousel
- поля scheduling/runtime auto-sync
- другие operational knobs уровня UI

Именно поэтому и `showcase.py`, и `backend-worker` читают и пишут `AdminUiSettings`.

## Перенос настроек
`SettingsTransferService` владеет flows import/export/reset сразу для нескольких config domains.

Текущая роль:

- экспорт unified payload, охватывающего pricing, sources, categories, weight и зоны brand mapping;
- import этих зон обратно в persistent state, контролируемое backend;
- выполнение одного полного path reset для state configuration, принадлежащего backend.

Этот service - cross-domain orchestrator для operational state, а не узкий serializer.

### Правила точности import/reset
Текущее поведение уже и более opinionated, чем подразумевает high-level список routes:
- `POST /settings/reset` не принимает selector payload и выполняет один полный path reset
- reset очищает DB state, принадлежащий backend, но не возвращает `config/sources.json` parser-service к defaults
- import patch'ит source settings, backed by parser-service, только когда live source service удается сопоставить по normalized host
- imported `auto_sync_period_minutes` ограничивается минимальным значением `60`
- payloads transfer переносят operational configuration, но не transient runtime state jobs/events

## Поведение ошибок и fallback
Router settings содержит несколько defensive fallbacks:

- ошибки загрузки weight rules могут возвращать empty lists вместо поломки UI;
- генерация parser-contract откатывается к empty payload с logged exception;
- listing products с missing weight также откатывается к empty list при failure.

Это сохраняет отзывчивость admin screens, но может маскировать operational problems, если logs не мониторятся.

## Оговорка о связности pricing и dedup
Payload pricing/settings по-прежнему публикует `dedup_only_available_products`, но текущая генерация candidates dedup остается фактически available-only вне зависимости от этого сохраненного flag.

## Текущие наблюдения по связности
- Логика pricing глубоко встроена в сборку responses product/catalog.
- Config supplier source разделен: выбор source находится в `sources.py`, а определения tariffs - в services settings/pricing.
- Состояние showcase частично моделируется как settings admin UI, поэтому operational configuration UI и public media state используют общее storage.
- Правила веса одновременно являются и settings, редактируемыми admin, и live cross-service API contract.
