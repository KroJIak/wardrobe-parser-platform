# 02. Conceptual Chen Model

> [!info]
> Это концептуальная модель.
> Она описывает **смысловые сущности** и их отношения, без SQL-деталей.

## 1. Главная идея

Новый товарный контур должен строиться вокруг двух разных сущностей:

- `Product` — канонический товар каталога;
- `ProductListing` — товар конкретного источника.

Текущая ошибка старой схемы заключалась в том, что эти две сущности были насильно слиты в одну.

## 2. Концептуальные сущности

### 2.1. Product

Это сущность каталога, которой управляет бизнес и админка.

У нее есть:

- финальный публичный дизайнер;
- выбранный primary listing для базовых текстов;
- канонический пол;
- коммерческий режим продажи;
- ручной вес, если админ его задал;
- ссылку на активное правило веса, если source-веса нет;
- статус жизненного цикла;
- статус видимости;

Но у нее **нет**:

- собственного базового source-like title/description дубля;
- собственного хранимого итогового веса;
- source URL как доменного ядра;
- source handle;
- source variant identity;
- source image list как единственного источника правды.

### 2.2. ProductListing

Это карточка товара в конкретном источнике.

Она хранит:

- source;
- url;
- handle;
- external_id;
- базовые title/description товара;
- исходные source-тексты;
- ingest-status;
- source-specific orderability snapshot;
- время последнего обнаружения и последней синхронизации.

> [!note]
> Для `sync`-listing это тексты, пришедшие из магазина.
> Для `manual`-listing это тексты, введенные админом как базовое содержимое товара.

> [!note]
> `ProductListing` — атомарная sync-сущность.
> Дедуп не смешивает несколько listing в один listing, а собирает витринный `Product` из набора listing.

### 2.3. ProductListingMember

Это связь между витринным `Product` и атомарным `ProductListing`.

Она нужна, чтобы:

- один витринный товар мог состоять из нескольких source-листингов;
- merge создавал новый товар из плоского union listing;
- цепочки вида `AB + C` на уровне данных превращались сразу в набор `{A, B, C}`.

И дополнительное правило:

- один listing в каждый момент времени принадлежит только одному текущему витринному `Product`.

### 2.4. ProductListingVariant

Это вариант внутри source listing.

Хранит:

- порядок;
- source ref;
- sku;
- title;
- price;
- currency;
- availability.

### 2.5. ProductListingImage

Это изображение, приехавшее из источника.

### 2.6. ProductPresentation

Это ручные правки админа для каталога:

- title override;
- description text;
- description html;
- description visibility;

Это именно editorial-слой поверх канонического товара.
Он не подменяет саму сущность `Product`, а лишь позволяет витрине и admin UI жить с ручной надстройкой поверх базовых полей primary listing, которую можно отдельно сбросить.

### 2.7. ProductListingGalleryImage

Это конечный стек изображений конкретного member-listing, который увидит витрина:

- source image;
- uploaded image asset;
- hidden flag;
- explicit order.

Она нужна, чтобы при выборе варианта UI мог:

- показать источник этого варианта;
- показать только фотографии именно его listing;
- не смешивать стеки фото разных сайтов в одну кашу.

### 2.8. ProductPriceOverride

Это отдельная сущность ручной рублевой цены товара:

- ручная цена в рублях;
- ручная старая цена в рублях для эффекта скидки.

Она не подменяет source price и не является частью editorial override.

### 2.9. Designer / DesignerSourceName

Нужны для разделения:

- исходного бренда;
- финального публичного дизайнера каталога.

### 2.10. CatalogFilter / CatalogFilterNode

Нужны для дерева фильтров и мультифильтров.

### 2.11. CustomCatalog

Нужен для ручных витринных списков товаров.

### 2.12. ProductDedupDecision

Нужна для явного журнала решений merge/reject.
При merge она должна указывать новый витринный `Product`, который стал результатом объединения,
а входные товары хранить отдельными member-строками без дублирования роли результата.

### 2.13. ShowcaseCategory

Нужна для фиксированных верхних категорий витрины:

- Новинки
- Дизайнеры
- Мужское
- Женское
- Скидки

Это seeded-справочник.
Админ не создает и не удаляет эти категории вручную.

## 3. Chen-style conceptual diagram

> [!note]
> Mermaid в Obsidian не поддерживает полноценную нотацию Чена с атрибутами-овалами и ромбами как отдельный тип диаграммы.
> Поэтому ниже используется Chen-style представление через `flowchart`, а ниже в документе — строгая ER/UML аппроксимация.

```mermaid
flowchart LR
  Product[Entity: Product]
  Listing[Entity: ProductListing]
  ListingMember[Entity: ProductListingMember]
  Variant[Entity: ProductListingVariant]
  Image[Entity: ProductListingImage]
  Source[Entity: Source]
  Presentation[Entity: ProductPresentation]
  ListingGalleryImage[Entity: ProductListingGalleryImage]
  PriceOverride[Entity: ProductPriceOverride]
  Designer[Entity: Designer]
  DesignerName[Entity: DesignerSourceName]
  DedupDecision[Entity: ProductDedupDecision]

  R1{composed_from}
  R2{has}
  R3{comes_from}
  R4{overridden_by}
  R5{displayed_with}
  R5a{priced_with}
  R6{normalized_into}
  R7{decides_on}

  Product --- R1 --- ListingMember
  Listing --- R1 --- ListingMember
  Listing --- R2 --- Variant
  Listing --- R2 --- Image
  Source --- R3 --- Listing
  Product --- R4 --- Presentation
  Product --- R5 --- ListingGalleryImage
  Listing --- R5 --- ListingGalleryImage
  Product --- R5a --- PriceOverride
  DesignerName --- R6 --- Designer
  Product --- R6 --- Designer
  DedupDecision --- R7 --- Product
```

## 4. Physical ER approximation

```mermaid
erDiagram
  PRODUCTS ||--o{ PRODUCT_LISTING_MEMBERS : composed_from
  PRODUCT_LISTINGS ||--o{ PRODUCT_LISTING_MEMBERS : included_in
  SOURCES ||--o{ PRODUCT_LISTINGS : publishes
  PRODUCT_LISTINGS ||--o{ PRODUCT_LISTING_VARIANTS : has
  PRODUCT_LISTINGS ||--o{ PRODUCT_LISTING_IMAGES : has
  PRODUCTS ||--o| PRODUCT_PRESENTATION : overridden_by
  PRODUCTS ||--o{ PRODUCT_LISTING_GALLERY_IMAGES : displayed_with
  PRODUCT_LISTINGS ||--o{ PRODUCT_LISTING_GALLERY_IMAGES : displayed_with
  PRODUCTS ||--o| PRODUCT_PRICE_OVERRIDES : priced_with
  PRODUCT_DEDUP_DECISIONS ||--o{ PRODUCT_DEDUP_DECISION_MEMBERS : records
  DESIGNERS ||--o{ PRODUCTS : owns
  DESIGNERS ||--o{ DESIGNER_SOURCE_NAMES : absorbs
  FILTERS ||--o{ FILTER_NODES : expands
  FILTERS ||--o{ FILTER_LOCAL_CATEGORY_KEYWORDS : matches
  FILTERS ||--o{ FILTER_TITLE_KEYWORDS : matches
  FILTERS ||--o{ FILTER_MANUAL_PRODUCTS : pins
  CUSTOM_CATALOGS ||--o{ CUSTOM_CATALOG_PRODUCTS : contains
  SHOWCASE_CATEGORIES ||--o{ SHOWCASE_CATEGORY_ATTACHMENTS : owns
```

## 5. Самые важные смысловые разделения

### Product != ProductListing

Если их не разделить, снова возникают:

- `dedup://...`;
- конфликт ручного и source товара;
- путаница между базовым listing title и editorial override;
- невозможность нормально поддерживать multi-source future.

### Commercial availability != Source orderability

Если их не разделить, снова смешаются две разные вещи:

- что уже физически есть у продавца на руках (`В наличии`);
- что пока можно только заказать из источника (`Под заказ`);
- и что в самом source сейчас вообще можно или нельзя выкупить.

### Manual ruble price != Source price != Derived price

Если их не разделить, снова смешаются:

- price у source variant;
- итоговая derived рублевая цена после формулы;
- ручная рублевая цена админа;
- старая рублевая цена для эффекта скидки.

### Designer != Source Brand

Если их не разделить, невозможно качественно реализовать:

- слияние нескольких source brand в одного публичного дизайнера;
- единое финальное имя дизайнера на товаре, в фильтрах и на отдельной странице;
- единое описание дизайнера.

### Filter != ShowcaseCategory

Если их не разделить, UI верхней навигации опять начнет диктовать структуру данных напрямую.

### Category != Filter

Если их не разделить, локальная классификация товара снова смешается с витринной навигацией и rule-based фильтрами.

### ListingVariant != ProductVariant

На текущем admin-продукте нужен именно source-level вариант.
Канонический variant entity пока не обязателен.
Поэтому в новой модели нужен `ProductListingVariant`, а не искусственный “глобальный вариант товара”.
