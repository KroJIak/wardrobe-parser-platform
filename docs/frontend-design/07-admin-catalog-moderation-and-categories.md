# Проектирование фронтенда: модерация каталога и категории в admin

## Охват
- Охватывает: вкладку products, паттерн навигации по product-card, поток ручного создания и редактирования продуктов, вкладку dedup, вкладку categories, дерево и редактор категорий, ручные привязки.
- Не охватывает: sources, pricing, designers, weight, settings и управление учетными записями.
- Зависит от: `src/admin/admin-products-tab.tsx`, `src/admin/admin-dedup-tab.tsx`, `src/admin/admin-categories-tab.tsx`, связанных hooks и модальных окон.

## Поверхность модерации продуктов
Зона модерации продуктов сосредоточена вокруг вкладки `products`.

Основные строительные блоки:
- `AdminProductsTab`
- `AdminProductsFilters`
- `AdminProductsTable`
- `useAdminProductsTable`
- `useAdminProductFilters`
- `useAdminProductCreateMock`
- `AdminManualProductEditModal`

### Используемые источники данных
- provider `products`
- provider `sources`
- методы мутаций provider для:
  - preview/probe по URL
  - ручного создания продукта
  - ручного обновления продукта
  - загрузки изображения по файлу или URL
  - обновления overrides
  - изменения статуса
  - назначения starred category

### Поведение списка продуктов
Вкладка рендерит:
- общие счетчики продуктов
- filters по source/vendor/type/status
- searchable products table
- бесконечный скролл через provider `loadMoreProducts()`

Продукты со статусом `unavailable` уже отфильтрованы на уровне provider до передачи таблице.

## Создание и редактирование продуктов
`useAdminProductCreateMock()` обеспечивает работу shell-level modal создания продукта.

Возможности:
- наполнение draft по preview URL источника
- наполнение draft по поиску уже существующего продукта
- привязка ручного продукта к source URL или `source_id`
- загрузка ручных изображений
- управление favorite category
- опциональное скрытие существующего продукта, обнаруженного при lookup

Поток ручного редактирования продукта также существует внутри `AdminSourcesTab` для продуктов, привязанных к конкретному источнику.

## Паттерн навигации по продукту
Карточки продуктов в admin используют `useAdminProductNavigation()`:
- обычный клик -> `navigate("/product/:id?from=admin")`
- средний клик / ctrl-click / cmd-click -> `window.open(...)`

Эта форма навигации нацелена на product-route публичного сайта, а не на чисто admin-route.

## Поверхность дедупликации
Зона dedup сосредоточена вокруг `AdminDedupTab`.

Существуют два подвида представления:
- `candidates`
- `decisions`

`AdminDedupCandidatesView` поддерживает:
- открытие левого и правого продукта
- merge пары
- combine пары
- reject пары
- бесконечную дозагрузку

`AdminDedupDecisionsView` поддерживает:
- просмотр исторических решений
- отмену решения, когда это разрешено
- бесконечную дозагрузку

Provider экспортирует datasets кандидатов и решений отдельно, включая независимые flags загрузки и пагинации.

## Эффекты dedup-мутаций
Dedup-мутации вызывают действия provider:
- `mergeDedupPair()`
- `rejectDedupPair()`
- `combineDedupPair()`
- `undoDedupDecision()`

После мутации стратегия refresh у provider такова:
- products
- categories
- dedup candidates

Это отражает тот факт, что изменения dedup влияют на видимость каталога и category counts, а не только на экран dedup.

## Поверхность категорий
Зона категорий сосредоточена вокруг `AdminCategoriesTab`.

Основные строительные блоки:
- `AdminCategoryTree`
- `AdminCategoryEditorPanel`
- `AdminCategoryManualProducts`
- `useAdminCategories`

### Поведение дерева
Дерево:
- рендерит вложенные admin-категории
- поддерживает выбор узла
- поддерживает создание нового корня или дочерней категории
- показывает loading-state, связанный со счетчиками

### Поведение редактора
Панель редактора поддерживает:
- rename с отложенным autosave
- toggle включения и выключения
- favorite toggle
- удаление
- local keywords
- title keywords
- ручное прикрепление продукта для редактируемых leaf-категорий

## Автосохранение категории и ручное назначение
`useAdminCategories()` содержит несколько локальных рабочих потоков:
- отложенное сохранение rename
- debounced-поиск ручных продуктов
- автоматическую загрузку уже назначенных ручных продуктов при выборе валидной leaf-категории
- guarded-операции с keywords, когда категория заблокирована для редактирования

Поток ручной привязки category-product:
1. выбрать редактируемую leaf-категорию
2. найти продукты
3. прикрепить продукт через `POST /categories/{id}/manual-products`
4. обновить назначенный список и datasets продуктов и категорий

## Области действия ключевых слов категорий
Текущие операции с ключевыми словами поддерживают два явно используемых в admin UI scope:
- `local`
- `title`

Нижележащие действия provider также принимают `status`, но основной поток category editor в исследованном UI напрямую использует только inputs для `local` и `title`.

## Общая роль в системе
Эти три группы фич образуют ядро модерации во frontend:
- products -> просмотр и формирование отдельных записей каталога
- dedup -> разрешение конфликтов между продуктами
- categories -> организация видимого дерева каталога и курируемого размещения продуктов
