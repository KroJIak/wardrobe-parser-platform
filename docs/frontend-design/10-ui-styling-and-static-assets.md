# Проектирование фронтенда: UI-стили и статические ассеты

## Охват
- Охватывает: стратегию глобального CSS, общие UI-примитивы, icons, skeletons, brand assets, HTML-оболочки, поведение статической раздачи.
- Не охватывает: бизнес-логику или API orchestration.
- Зависит от: `src/styles.css`, `src/shared/*`, `public/*`, `apps/*/index.html`, `nginx/nginx.conf`.

## Стратегия стилизации
Текущий frontend в основном оформляется через одну глобальную таблицу стилей:
- `src/styles.css`

Несмотря на то что Tailwind tooling настроен в Vite, активная реализация в основном опирается на вручную написанные CSS-классы, а не на utility-driven composition.

## Глобальная визуальная область
`src/styles.css` стилизует сразу обе сборки:
- placeholder-оболочку сайта
- страницу login admin-приложения
- topbar и общий shell
- UI каталога
- dedup-cards
- формы, теги, pills, таблицы, кнопки
- responsive-поведение для основных layouts
- индикатор смены маршрута

Разделения на CSS-modules или отдельные таблицы стилей по приложениям нет.

## Базовая тема
Характеристики текущей базовой темы:
- светлый нейтральный фон (`#f6f6f6`)
- темный текст (`#111111`)
- sans-serif stack в стиле system/Helvetica
- белые карточки с мягкими границами
- сдержанное использование blue-gray accents в интерактивных состояниях

Заглушка сайта использует отдельный теплый gradient background и крупную uppercase-типографику для `be monki`.

## Общие UI-примитивы
Общие переиспользуемые UI-элементы находятся в `src/shared/`:
- `SiteHeader`
- `ToastStack`
- `EmptyState`
- варианты `Skeleton`
- `ImageWithFallback`
- `LatexBrand` / `LazyLatexBrand`
- монохромные icon-components в `mono-icons.tsx`

Эти примитивы используются и в admin-коде, и в спящем коде сайта.

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
- панелей каталога и root-категорий
- product-page

Это сохраняет визуальную согласованность loading-state, хотя загрузкой данных управляют многие разные hooks.

## Типографика и рендеринг формул
Для отображения pricing и брендов используются дополнительные render-слои:
- KaTeX CSS импортируется в `src/admin/admin-page.tsx`
- `LatexBrand` и `LazyLatexBrand` рендерят имена брендов через KaTeX-aware components
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

Они не делают preload дополнительных ассетов и не добавляют app-specific orchestration скриптов за пределами `main.tsx`.

## Поведение статической раздачи
В контейнерном рантайме nginx:
- раздает собранный Vite output как статические файлы
- использует fallback на `index.html` для client-side routes
- проксирует `/api/` на backend
- отдает `/health`
- ограничивает размер тела запроса на уровне `100 MB`

Это означает, что URL ассетов вроде `/logo_anton_shell.svg` раздаются nginx напрямую из собранного статического дерева.

## Текущая граница presentation-layer
Presentation-layer во frontend технически общий для обоих приложений, но визуально сильнее ориентирован на:
- полноценный admin UI
- спящий, но уже стилизованный catalog/product site
- текущую активную публичную homepage-заглушку

Поэтому система стилизации шире, чем текущий mounted site-runtime, поскольку все еще несет CSS, необходимый для спящих catalog/product flows.
