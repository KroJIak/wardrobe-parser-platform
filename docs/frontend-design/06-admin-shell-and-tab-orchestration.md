# Проектирование фронтенда: admin shell и orchestration вкладок

## Охват
- Охватывает: `AdminPage`, переключение вкладок, жизненный цикл shell, topbar, overlays, обработку toast-уведомлений, preload на уровне вкладок.
- Не охватывает: детальное поведение products/categories/pricing внутри каждой вкладки.
- Зависит от: `src/admin/admin-page.tsx`, `src/admin/admin-tab-content.tsx`, `src/admin/admin-tabs.tsx`, `src/admin/hooks/use-admin-*`.

## Модель shell
Admin-приложение представляет собой один routed shell, который переключает содержимое вкладок внутри одного page-компонента.

Основные shell-файлы:
- `admin-app.tsx`
- `admin-page.tsx`
- `admin-tabs.tsx`
- `admin-tab-content.tsx`
- `admin-topbar.tsx`
- `admin-overlays.tsx`

## Ответственность `AdminPage`
`AdminPage` является главным orchestration-компонентом активного frontend-runtime.

Он отвечает за:
- чтение активной вкладки из route-параметров
- вызов `useLiveData()` и распаковку большей части provider-state и actions
- создание feature-local hooks для:
  - жизненного цикла вкладок
  - фильтрации products table
  - редактирования категорий
  - dedup-взаимодействий
  - pricing runtime и draft-состояний
  - auto-save настроек source pricing
  - управления sync
  - import/export/reset настроек
  - управления showcase media
  - редактирования weight-rules
  - brand mapping
  - поведения modal для создания продукта
- подключения overlays и toast stack
- сборки props для `AdminTabContent`

Тем самым `AdminPage` одновременно является и контейнером shell, и верхнеуровневым интегратором фич.

## Поток выбора вкладки
1. `useParams()` читает `tab`
2. `normalizeAdminTab()` валидирует его по известному набору вкладок
3. `useAdminPageLifecycle()` перенаправляет некорректные вкладки на `/control/{normalized-tab}`
4. `AdminTabs` рендерит strip вкладок
5. `AdminTabContent` переключается по нормализованному ключу вкладки и рендерит нужный tab-компонент

Переключение реализовано явными условными ветками, а не через registration map или lazy route loader.

## Политика preload для вкладок
`useAdminTabPreload()` запускается при смене активной вкладки.

Текущее поведение preload:
- `pricing` -> принудительно загружает pricing settings
- `settings` -> принудительно загружает admin UI settings
- `weight` -> загружает weight rules и продукты без веса
- `dedup` -> загружает dedup candidates
- `categories` -> загружает дерево категорий
- `sources` -> загружает sources и admin UI settings
- `products` -> refresh sources

Это означает, что сама активация вкладки уже является событием загрузки данных.

## Визуальная оболочка shell
### Верхняя панель
`AdminTopbar` переиспользует `SiteHeader` и предоставляет:
- ссылку на `/`
- кнопку logout

Брендовый ассет в topbar использует тот же SVG, что и chrome публичного сайта.

### Вкладки
`AdminTabs` рендерит плоский ряд кнопок по константному списку `tabs`.

### Секция head и метаданные
`AdminHead` используется внутри `AdminPage` для shell-level metadata и summary display. Заголовок документа также устанавливается через `useAdminPageLifecycle()` и helper-функции на уровне маршрутов.

## Слой оверлеев
`AdminOverlays` централизует UI, который должен находиться вне tab-content:
- toast stack
- modal создания продукта
- modal увеличенного изображения

Это позволяет держать состояние модальных окон в `AdminPage`, но рендерить дерево overlays только один раз.

## Модель toast-уведомлений
Создание toast-уведомлений локализовано внутри shell:
- `useToasts()` возвращает `pushToast`, `closeToast`, `pauseToast`, `resumeToast`
- `AdminPage` создает один контроллер toast-уведомлений и передает его вниз
- `AdminOverlays` рендерит `ToastStack`

Большинство feature-hooks возвращают `{ ok, message }`, а shell уже сам решает, когда показывать это сообщение.

## Кластеры feature-hooks, используемые shell
| Hook | Роль |
|---|---|
| `useAdminSyncControls` | оборачивает действия запуска и отмены sync |
| `useAdminSettingsTransfer` | управляет browser-потоком export/import/reset файлов |
| `useAdminProductCreateMock` | orchestrates modal создания продукта |
| `useAdminDedupActions` | держит состояние и dispatch действий dedup |
| `useAdminCategories` | управляет состоянием редактора категорий и autosave |
| `useAdminPricingRuntime` | обрабатывает pricing example и feedback от Bybit worker |
| `useAdminSourcePricing` | ведет draft-state и отложенное сохранение source pricing |
| `useAdminWeightRules` | управляет редактированием weight с debounce |
| `useAdminBrandMapping` | загружает и сохраняет состояние вкладки designers |
| `useAdminShowcase` | управляет upload и ordering для hero/carousel |

## Межфичевая связность
Admin shell намеренно разделяет один provider и один page-level coordinator между всеми вкладками. В результате:
- вкладки не изолированы как micro-frontends
- shell-hooks часто зависят от provider-datasets из других feature-областей
- одна мутация может инициировать refresh datasets, используемых несколькими вкладками

Примеры:
- dedup-actions обновляют products и categories
- import/reset настроек обновляет sources, pricing, categories и weight
- изменения pricing supplier обновляют и pricing, и sources

## Ограничение shell
Текущая архитектура предпочитает одну большую интегрированную control-plane-поверхность вместо маленьких независимо маршрутизируемых admin-страниц. Это уменьшает дублирование между страницами, но концентрирует большой объем orchestration внутри `AdminPage`.
