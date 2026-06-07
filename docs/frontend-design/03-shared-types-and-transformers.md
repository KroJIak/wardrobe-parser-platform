# Проектирование фронтенда: общие типы и преобразователи

## Охват
- Охватывает: локальный слой TypeScript-моделей, frontend-типы по фичам, helper-функции форматирования, утилиты формирования полей, helpers для изображений и slug.
- Не охватывает: инвентарь endpoint-ов или оркестрационный поток внутри provider.
- Зависит от: `src/shared/live-data-types.ts`, `src/admin/admin-types.ts`, `src/admin/admin-formatters.ts`, `src/shared/utils.ts`, `src/shared/product-image.ts`, `src/site/catalog-helpers.ts`.

## Модель владения типами
Frontend не импортирует сгенерированные контракты из backend-схем. Вместо этого он поддерживает вручную написанные локальные типы в двух основных группах:

| Файл | Роль |
|---|---|
| `src/shared/live-data-types.ts` | cross-feature модели данных, используемые provider-state и API-hooks |
| `src/admin/admin-types.ts` | draft-структуры, enums и производные UI-модели, специфичные для admin-view |

Кроме того, внутри feature-файлов существуют payload-типы на уровне отдельных компонентов, например:
- `AdminSourcesTab`
- `AdminSettingsAccountsSection`
- `CatalogPage`
- `ProductPage`

## Основные семейства общих данных
`src/shared/live-data-types.ts` содержит основные browser-модели, обращенные к домену:
- `Source`
- `ServiceProduct`
- `ProductVariant`
- `ProductEditState`
- `JobsLatest`
- `SyncJobHistoryItem`
- `SourceRunItem`
- `CategoryView`
- `AdminCategoryNode`
- `CategoryManualProduct`
- `DedupCandidate`
- `DedupDecision`
- `ProductUrlPreview`
- `WeightRule`
- `WeightMissingProduct`
- `PricingSettings`
- `PricingSupplier`
- `AdminUiSettings`
- `SettingsTransferPayload`
- `LiveDataContextValue`

Эти типы используются напрямую и как ожидания для API payload, и как in-memory UI-state.

## Соглашение по именованию полей
Текущий frontend напрямую отражает backend-именование JSON-полей:
- JSON-поля остаются в `snake_case`
- TypeScript interfaces также сохраняют `snake_case`
- компоненты обращаются к полям вроде `created_at`, `source_id`, `is_enabled`

Это устраняет отдельный слой сериализации на стороне клиента, но одновременно жестко связывает UI с именами полей backend.

## Канонические паттерны преобразований в текущем коде
Хотя универсального слоя DTO-mapper нет, код постоянно выполняет локальные преобразования.

### 1. Дерево admin-категорий -> дерево публичных категорий
В `LiveDataProvider` массив `AdminCategoryNode[]` преобразуется в `CategoryView[]` через:
- фильтрацию до включенных корней
- проекцию счетчиков и флагов
- рекурсивное отсечение выключенных дочерних узлов

### 2. Нормализация статуса продукта
`src/site/catalog-helpers.ts` преобразует backend-строки статусов в UI-ориентированные корзины:
- `available`
- `out_of_stock`
- запасной вариант `hidden`

### 3. Формирование отображения валют и денег
Helper-функции форматирования преобразуют числовые backend-поля в display-строки в нескольких местах:
- `admin-formatters.ts`
- `catalog-page.tsx`
- `product-page.tsx`
- `admin-sync-formatters.ts`

### 4. Нормализация URL изображений
`src/shared/product-image.ts`:
- нормализует исходные URL изображений
- добавляет provider-specific query params для оптимизации
- выводит primary image продукта из `image_urls`

### 5. Формирование slug
`src/shared/utils.ts` экспортирует `toSlug()`, который:
- транслитерирует кириллицу в ASCII
- переводит строку в нижний регистр и удаляет неподдерживаемые символы
- используется catalog-helper-ами как fallback-источник slug категории

## Типы UI-draft-слоя
Логика admin-фич создает дополнительные структуры draft-слоя, которые не предназначены для точного зеркалирования backend-ответов:
- pricing-drafts в виде строк для редактирования с debounce
- draft-значения сумм в трех валютах
- draft-map для weight rules
- draft-структуры для ручного создания и редактирования продуктов
- списки элементов carousel для showcase
- состояние строк в brand-mapping

Эти типы существуют для поддержки частично отредактированного состояния форм до момента сохранения.

## Размещение transformers
Логика преобразований сейчас распределена, а не централизована:

| Зона | Примеры |
|---|---|
| `src/shared/` | projection категорий, helpers для изображений, JSON-обертки API |
| `src/admin/` | view-model для pricing example, sync-formatters, helpers для status badges |
| `src/site/` | фильтры каталога, формирование статусов, mapping имен источников |
| уровень отдельного компонента | modal-drafts, адаптация fetch-payload, display-formatting |

## Последствия текущей модели
- Frontend можно быстро менять локально, потому что не требуется шаг генерации.
- Одна и та же доменная сущность может существовать как:
  - raw API shape
  - provider shape
  - draft form shape
  - derived display model
- Логика mapping-а явно присутствует в коде, но распределена по многим файлам.
- Граница между каноническими данными и UI-derived state существует, но не закреплена отдельным contract-слоем.

## Заметные общие helpers
| Helper | Назначение |
|---|---|
| `apiJson()` / `apiNoContent()` | типизированные API-обертки вокруг `authFetch()` |
| `normalizeImageSourceUrl()` / `optimizeImageUrl()` | формирование URL изображений |
| `getProductPrimaryImageUrl()` | вычисление первого изображения |
| `toSlug()` | транслитерация и нормализация slug |
| `normalizeProductStatus()` | нормализация статуса продукта для site UI |
| `deriveStatusAfterUnhide()` | вывод видимого статуса по доступности variants |

## Практическое правило для feature-кода
Feature-компоненты обычно потребляют общие типы напрямую, а затем накладывают поверх них локальные draft-модели. Отдельной границы пакетов вида `service DTO -> view model` нет; шаг преобразования происходит рядом с consuming hook или экраном.
