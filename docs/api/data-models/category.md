# Модель данных: Category

## Область действия
Эта модель покрывает управление деревом категорий в admin, публичные деревья категорий каталога и ручные связи product-category.

## Узел категории admin
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `id` | `int` | да | id категории |
| `name` | `string` | да | отображаемое имя |
| `slug` | `string` | да | уникальный slug |
| `parent_id` | `int \| null` | нет | id родительской категории |
| `is_fallback` | `bool` | да | fallback-category для matching |
| `is_favorite` | `bool` | да | starred category для showcase/catalog |
| `is_enabled` | `bool` | да | включена в публичном/admin дереве |
| `is_system` | `bool` | да | маркер системной/неудаляемой ветки |
| `has_children` | `bool` | да | helper для UI |
| `keywords_editable` | `bool` | да | можно ли менять keywords |
| `keywords_locked_reason` | `string \| null` | нет | пояснение для UI |
| `is_designers_root` | `bool` | да | маркер корня ветки designers |
| `is_in_designers_branch` | `bool` | да | потомок ветки designers |
| `product_count` | `int` | да | текущее число продуктов |
| `keywords` | `array<string>` | да | локальный список keywords |
| `title_keywords` | `array<string>` | да | keywords с областью title |
| `status_keywords` | `array<string>` | да | keywords с областью status |
| `effective_keywords` | `array<string>` | да | итоговый resolved-набор keywords |
| `children` | `array<admin-category-node>` | да | рекурсивные дети |

## Узел категории публичного каталога
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `slug` | `string` | да | slug категории |
| `name` | `string` | да | отображаемое имя |
| `count` | `int` | да | число продуктов |
| `is_designers_root` | `bool` | да | маркер корня ветки designers |
| `is_in_designers_branch` | `bool` | да | маркер потомка |
| `children` | `array<catalog-category-node>` | да | рекурсивные дети |

## Ручная связь продукта с категорией
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `product_id` | `int` | да | id связанного продукта |
| `source_id` | `int` | да | id источника |
| `source_name` | `string \| null` | нет | отображаемое имя источника |
| `title` | `string` | да | title продукта |
| `url` | `string` | да | URL продукта |
| `status` | `string` | да | статус продукта |
| `image_url` | `string \| null` | нет | первое изображение продукта |
| `category_names` | `array<string>` | да | назначенные имена категорий |

## Представления по доменам
### `frontend`
- `AdminCategoryNode`
- `CategoryView`
- `CategoryManualProduct`

### `backend`
- `CategoryTreeNodeResponse`
- `CatalogCategoryNodeResponse`
- `CategoryManualProductResponse`
- mutation requests:
  - create/update category
  - add/remove keyword
  - add/remove manual product

### `database`
- `parser_category`
- `parser_category_keyword`
- `parser_category_manual_product`
- `parser_product_category_match`
- `parser_category_count_snapshot`
- `parser_category_index_state`

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `database` |
|---|---|---|---|
| `count` | `CategoryView.count` | ответ каталога | projection из `parser_category_count_snapshot` |
| варианты `keywords` | те же имена | admin response | разбиение `parser_category_keyword.keyword_scope` на local/title/status |
| `children` | рекурсивно | рекурсивно | relation parent-child на `parser_category.parent_id` |

## Текущие ограничения
- Payload публичных категорий является сокращенной projection admin-дерева.
- Match-связи category/product хранятся отдельно от ручных assignments product.
- Поведение ветки designers является backend read-side concern, наложенным поверх `parser_category`.
