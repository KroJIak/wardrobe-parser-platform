# Проектирование фронтенда: UI-стили и статические ассеты

## Охват
- Охватывает: стратегию CSS, общие UI-примитивы, icons, skeletons, brand assets, HTML-оболочки, поведение статической раздачи.
- Не охватывает: бизнес-логику или API orchestration.
- Зависит от: `src/styles.css`, `src/site/site.css`, `src/shared/*`, `public/*`, `apps/*/index.html`, `nginx/nginx.conf`.

## Стратегия стилизации
Текущий frontend использует две разные таблицы стилей:
- `src/styles.css` для `admin`
- `src/site/site.css` для `site`

Tailwind tooling настроен в Vite, но активная реализация в основном опирается на вручную написанный CSS-код.

## Глобальная визуальная область admin
`src/styles.css` стилизует `admin`-сборку:
- страницу login
- topbar и showcase shell
- `control` layout
- UI каталога и product page
- dedup-cards
- формы, теги, pills, таблицы, кнопки
- responsive-поведение для основных layouts
- индикатор смены маршрута

## Отдельная визуальная область site
`src/site/site.css` стилизует только `site`:
- базовые `html`, `body`, `#root`
- `.site-page`
- `.site-page__title`

Никакие admin-классы или admin-shell selectors в `site.css` не присутствуют.

## Базовая тема
`admin`:
- светлый нейтральный фон
- темный текст
- sans-serif stack
- карточки и tabular UI

`site`:
- теплый фон `#f6f1e8`
- serif stack (`Georgia`, `Times New Roman`)
- крупная типографика для `be monki`

## Общие UI-примитивы
Общие переиспользуемые UI-элементы находятся в `src/shared/`:
- `SiteHeader`
- `ToastStack`
- `EmptyState`
- варианты `Skeleton`
- `ImageWithFallback`
- `LatexBrand` / `LazyLatexBrand`
- монохромные icon-components в `mono-icons.tsx`

Практически эти примитивы сейчас в основном потребляются `admin`.

## Иконки
Frontend использует два источника иконок:
- custom SVG/icon wrappers из `src/shared/mono-icons.tsx`
- `lucide-react`

Использование смешанное и не стандартизовано через одну абстракцию.

## Скелетоны и UI загрузки
Компоненты skeleton в `src/shared/skeleton.tsx` обеспечивают placeholder-рендеринг для:
- products
- categories
- dedup
- pricing
- weight
- settings
- panels showcase/catalog
- product-page

Они относятся к активному `admin`-рантайму; `site` их не использует.

## Типографика и рендеринг формул
Для отображения pricing и брендов используются дополнительные render-слои:
- KaTeX CSS импортируется в `src/admin/admin-page.tsx`
- `LatexBrand` и `LazyLatexBrand` рендерят имена брендов
- секции pricing formula переиспользуют admin-formatting helpers и рендеринг legend

## Статические ассеты
Текущие ассеты в `public/`:
- `public/logo_anton_shell.svg`
- `public/favicon.png`

`SiteHeader` напрямую ссылается на `/logo_anton_shell.svg` как на общий brand mark.

## Роль HTML-оболочки
`apps/admin/index.html` и `apps/site/index.html` задают:
- язык документа
- viewport meta tag
- исходный title
- root-node для монтирования

Они не делают preload дополнительных ассетов и не добавляют app-specific orchestration скриптов.

## Поведение статической раздачи
В контейнерном рантайме nginx:
- раздает собранный Vite output как статические файлы
- использует fallback на `index.html` для client-side routes
- проксирует `/api/` на backend
- отдает `/health`
- ограничивает размер тела запроса на уровне `100 MB`

Это означает, что URL ассетов вроде `/logo_anton_shell.svg` раздаются nginx напрямую из собранного статического дерева.

## Текущая граница presentation-layer
Presentation-layer частично общий по ассетам и shared-components, но разделен по CSS:
- `admin` использует большой глобальный stylesheet
- `site` использует отдельный минимальный stylesheet

Именно поэтому `site` сейчас визуально изолирован от admin без отдельного репозитория.
