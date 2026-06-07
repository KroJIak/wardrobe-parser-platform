# Проектирование фронтенда: рантайм публичного сайта

## Охват
- Охватывает: текущий активный site-рантайм, спящую реализацию catalog/product, зависимости от shared/admin-кода, текущий паттерн использования публичного API.
- Не охватывает: внутреннее устройство admin-shell или реализацию backend-каталога.
- Зависит от: `src/site/site-app.tsx`, `src/site/*`, `src/shared/use-showcase-edit-permission.ts`, `src/shared/live-data-context.tsx`.

## Активный рантайм
Текущая смонтированная сборка `site` намеренно минималистична.

`SiteApp`:
- устанавливает `document.title = "Anton Shell"`
- рендерит центрированную placeholder-оболочку
- показывает ровно одну фразу: `be monki`

Он не:
- создает маршрутизатор
- создает shared provider-state
- монтирует catalog/product/layout pages

## Спящая site-реализация, присутствующая в исходниках
Репозиторий по-прежнему содержит более широкий code path публичного сайта:
- `layout.tsx`
- `home-page.tsx`
- `category-page.tsx`
- `catalog-page.tsx`
- `product-page.tsx`
- `catalog-hover-menu.tsx`
- `catalog-helpers.ts`

Этот код не является мертвым текстом; он структурирован, пригоден для импорта, но сейчас не используется активным `SiteApp`.

## Поведение спящего каталога
`CatalogPage` реализует UI публичного каталога со следующими возможностями:
- hover-навигация по root-категориям
- панели дочерних категорий
- поиск по продуктам
- фильтр по статусу
- фильтр по source
- cursor-based пагинация через `/catalog/products`
- optimistic actions для favorite-category и visibility для пользователей, которым разрешено редактировать showcase

Публичные данные каталога запрашиваются через raw `fetch()` к:
- `/api/v1/catalog/categories/roots`
- `/api/v1/catalog/categories/root/{slug}`
- `/api/v1/catalog/products`

Детали координации рантайма, которые по-прежнему присутствуют в этой спящей реализации:
- кэши root categories и slug-to-root resolution на уровне module scope
- ленивая загрузка root-панелей вместо полной eager-загрузки дерева
- abort для in-flight запросов каталога, которые не относятся к append-сценарию
- монотонные request-id guards, игнорирующие устаревшие ответы, пришедшие не по порядку

Одновременно этот код использует и admin-ориентированные действия provider:
- `useLiveData()` для `sources`
- `getProductStarredCategories()`
- `setProductStarredCategories()`
- `setProductStatus()`

## Поведение спящей product-страницы
`ProductPage` реализует более богатую публичную карточку продукта со следующими возможностями:
- gallery и выбор variant
- рендеринг breakdown по pricing
- редактирование title/description/image, когда viewer имеет permission на редактирование showcase
- управление hide/unhide для продукта
- upload изображений и редактирование порядка изображений

Она зависит от:
- `useLiveData()` для `getProductById()`, `updateProductOverrides()`, `setProductStatus()`, `uploadProductImage()`
- `ensurePricingLoaded()` для рендеринга pricing formula
- `useShowcaseEditPermission()` для gating редактирования
- `buildPricingExampleView()` из `src/admin/admin-pricing-view-model`
- helper-функций money и legend из `src/admin/admin-formatters`

Это означает, что спящая product-page не изолирована от admin-кода.

## Зависимость от общего chrome-слоя
`SiteLayout` переиспользует `SiteHeader` и сейчас встраивает admin-ориентированное поведение:
- CTA переключается между “Каталог товаров” и “Панель управления”
- logout-кнопка вызывает `logoutAdminSession()`
- target редиректа после logout равен `/login`

Этот layout предполагает аутентифицированный admin-aware контекст, а не чисто анонимный публичный сайт.

## Связность на уровне permission
`useShowcaseEditPermission()` является общим hook-ом, но его семантика ориентирована на admin-auth:
- он вызывает `/auth/me`
- он проверяет наличие `showcase.edit`
- он кэширует результат на уровне module scope

В результате спящие site-компоненты могут показывать controls редактирования на основании cookie admin-сессии.

## Вывод по публичному рантайму
Текущая site-кодовая база имеет два слоя:

### Слой 1: активный развернутый сайт
- одна placeholder-страница
- отсутствует data provider
- отсутствует публичная маршрутизация

### Слой 2: спящая реализация showcase/catalog
- функционально богатый catalog/product UI
- чтение публичного API и admin-aware controls редактирования
- зависимости от shared-state и helper-функций, предполагающих более широкий admin-stack
- логика request-cache и stale-response coordination, которая немедленно стала бы значимой при повторном монтировании спящего каталога

## Архитектурное следствие
Репозиторий уже подготовлен к более крупному публичному сайту, но смонтированный рантайм намеренно сужен до заглушки. Спящую site-реализацию следует рассматривать как присутствующую архитектуру исходников, а не как часть текущего активного user-facing runtime.
