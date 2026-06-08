# Проектирование фронтенда: admin shell и orchestration вкладок

## Охват
- Охватывает: только control-plane shell на маршрутах `/control/:tab` и orchestration внутри `AdminPage`.
- Не охватывает: showcase/catalog/product маршруты, которые обслуживаются отдельным `AdminShowcaseLayout`.
- Зависит от: `frontend/src/admin/admin-page.tsx`, `frontend/src/admin/admin-tab-content.tsx`, `frontend/src/admin/admin-tabs.tsx`, `frontend/src/admin/admin-topbar.tsx`, `frontend/src/admin/admin-head.tsx`, `frontend/src/admin/admin-overlays.tsx`, `frontend/src/admin/hooks/use-admin-*.ts*`.

## Граница shell
Control-plane shell активен только на:
- `/control/products`
- `/control/dedup`
- `/control/categories`
- `/control/designers`
- `/control/sources`
- `/control/pricing`
- `/control/weight`
- `/control/settings`

Маршруты `/`, `/catalog/*`, `/category/*`, `/product/:id` в этот shell не входят.

## Основные файлы shell
- `admin-page.tsx`
- `admin-tab-content.tsx`
- `admin-tabs.tsx`
- `admin-topbar.tsx`
- `admin-head.tsx`
- `admin-overlays.tsx`

## Роль `AdminPage`
`AdminPage`:
- читает `tab` из route params
- валидирует его через `normalizeAdminTab()`
- вызывает `useAdminPageLifecycle()` для canonical redirect и title
- распаковывает основной объем state/actions из `useLiveData()`
- собирает feature-local hooks
- формирует props для `AdminTabContent`
- держит toast/modal/image-zoom overlays

Это главный coordinator control-plane экрана.

## Выбор вкладки
Поток выбора выглядит так:
1. `useParams()` читает `tab`
2. `normalizeAdminTab()` приводит его к допустимому ключу
3. `useAdminPageLifecycle()` делает redirect на `/control/{normalized}`
4. `AdminTabs` показывает row кнопок
5. `AdminTabContent` рендерит конкретную вкладку через `if`-ветки

## Preload при смене вкладки
`useAdminTabPreload()` выполняет tab-specific загрузки:
- `pricing` -> `ensurePricingLoaded(true)`
- `settings` -> `ensureAdminUiLoaded(true)`
- `weight` -> `ensureWeightLoaded()`
- `dedup` -> `ensureDedupLoaded()`
- `categories` -> `ensureCategoriesLoaded()`
- `sources` -> `refreshSourcesOnly()` + `ensureAdminUiLoaded(true)`
- `products` -> `refreshSourcesOnly()`

Вкладки `designers` специального preload в этом hook не имеют.

## Shell UI
### `AdminTopbar`
Переиспользует `SiteHeader` и показывает:
- CTA `Каталог товаров` -> `/`
- logout-кнопку

### `AdminHead`
Рендерит:
- заголовок `Панель управления`
- sync actions
- кнопку создания товара
- `SyncSummary`

### `AdminOverlays`
Централизует:
- `ToastStack`
- `AdminProductCreateModal`
- zoom modal для изображений

## Используемые feature hooks
| Hook | Роль |
|---|---|
| `useAdminSyncControls` | run/cancel sync |
| `useAdminSettingsTransfer` | export/import/reset settings |
| `useAdminProductCreateMock` | modal создания продукта |
| `useAdminDedupActions` | merge/combine/reject/undo dedup flows |
| `useAdminCategories` | category editor state и autosave |
| `useAdminPricingRuntime` | pricing example и warnings |
| `useAdminSourcePricing` | source pricing drafts и debounce-save |
| `useAdminWeightRules` | weight drafts и debounce-save |
| `useAdminBrandMapping` | designers tab state |
| `useAdminShowcase` | hero/carousel media management |

## Практический итог
- `/control/:tab` остается одной большой интегрированной shell-поверхностью.
- Showcase/catalog/product runtime живет в том же приложении, но вне этого shell.
- Основная сложность сосредоточена в `AdminPage`, а не в маршрутизаторе или отдельном store на вкладку.
