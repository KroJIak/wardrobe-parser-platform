# Модель данных: Parser Product

## Область действия
Эта модель покрывает curated catalog products, которые возвращаются product-endpoints backend и хранятся в `parser_product`, включая projection категорий, pricing enrichment, edit overrides и lineage origin-variant.

## Каноническая структура продукта
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `id` | `int` | да | primary key продукта |
| `source_id` | `int` | да | id backend source-владельца |
| `handle` | `string` | да | handle source/product |
| `title` | `string` | да | effective title |
| `vendor` | `string \| null` | нет | raw vendor |
| `vendor_original` | `string \| null` | нет | исходный бренд источника в enriched reads |
| `vendor_mapped` | `string \| null` | нет | mapped brand |
| `vendor_display` | `string \| null` | нет | display brand после rules mapping |
| `product_type` | `string \| null` | нет | тип продукта в source |
| `url` | `string` | да | канонический или manual URL продукта |
| `price` | `float \| null` | нет | цена source/base |
| `currency` | `string` | да | отображаемая валюта |
| `source_price` | `float \| null` | нет | цена в валюте source на enriched views |
| `source_currency` | `string \| null` | нет | валюта source |
| `final_price` | `float \| null` | нет | вычисленная итоговая public/admin price |
| `final_currency` | `string \| null` | нет | итоговая валюта |
| `buyout_price_rub` | `float \| null` | нет | стоимость выкупа в RUB |
| `status` | `string` | да | см. lifecycle curated product в `enums.md` |
| `image_count` | `int` | да | общее число видимых изображений |
| `image_urls` | `array<string>` | да | текущие URL изображений |
| `variants` | `array<variant>` | да | payload variants продукта |
| `is_favorite` | `bool` | нет | маркер starred/favorite |
| `starred_category_ids` | `array<int>` | нет | назначенные favorite categories |
| `internal_category_id` | `int \| null` | нет | convenience-field основной категории |
| `internal_category_name` | `string \| null` | нет | имя основной категории |
| `internal_category_slug` | `string \| null` | нет | slug основной категории |
| `internal_category_ids` | `array<int>` | нет | полный набор matched category ids |
| `internal_category_names` | `array<string>` | нет | полный набор matched category names |
| `internal_category_slugs` | `array<string>` | нет | полный набор matched category slugs |
| `description` | `string \| null` | нет | effective description |
| `weight_grams` | `float \| null` | нет | вычисленный или manual weight |
| `weight_source` | `string \| null` | нет | источник веса |
| `weight_match_keyword` | `string \| null` | нет | совпавший keyword |
| `weight_value` | `float \| null` | нет | исходное значение веса |
| `weight_unit` | `string \| null` | нет | исходная единица веса |
| `pricing_manual_required` | `bool` | нет | warning-флаг UI на admin-enriched reads |
| `pricing_reason` | `string \| null` | нет | admin-заметка pricing |
| `pricing_components` | `object` | нет | детализация вычисления pricing |
| `product_edit` | `object` | нет | состояние edit-lock и image-override |
| `source_name` | `string \| null` | нет | денормализованное имя источника |
| `created_at` | `datetime \| null` | нет | timestamp создания строки |
| `updated_at` | `datetime \| null` | нет | timestamp обновления строки |

### Структура variant
| Поле | Тип | Описание |
|---|---|---|
| `title` | `string` | title variant |
| `option1/2/3` | `string \| null` | labels options при наличии |
| `available` | `bool` | флаг наличия |
| `price` | `string \| number \| null` | raw цена variant |
| `inventory_quantity` | `int` | количество или proxy доступности |
| `sku` | `string \| null` | SKU |

### Структура product edit
| Поле | Тип | Описание |
|---|---|---|
| `title_sync_locked` | `bool` | title отвязан от sync source |
| `description_sync_locked` | `bool` | description отвязан от sync source |
| `description_visible_override` | `bool \| null` | ручная видимость description |
| `description_visible_effective` | `bool` | effective видимость description |
| `images_sync_locked` | `bool` | sync изображений отключен |
| `title_override` | `string \| null` | ручной title |
| `description_override` | `string \| null` | ручное description |
| `hidden_source_image_urls` | `array<string>` | скрытые source images |
| `manual_image_urls` | `array<string>` | uploaded manual images |
| `manual_image_order` | `array<string>` | упорядоченные tokens изображений, например `m:/api/v1/products/images/{id}` |
| `source_image_urls` | `array<string>` | URL source images до overlay |

## Представления по доменам
### `frontend`
- `ServiceProduct`
- `ProductVariant`
- `ProductEditState`

### `backend`
- `ProductResponse`
- `ShowcaseProductResponse` добавляет поля pricing/public-view

### `database`
- `parser_product`
- `parser_product_origin_variant`
- `parser_favorite_product`
- таблицы matches категорий дают projections `internal_category_*` во время чтения

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `database` |
|---|---|---|---|
| `image_urls` | `image_urls` | `image_urls` | `parser_product.image_urls` JSON |
| `variants` | `variants` | `variants` | `parser_product.variants` JSON |
| `product_edit` | `product_edit` | собранный dict | колонки `title_*`, `description_*`, `manual_image_*`, `hidden_source_image_asset_ids` |
| `is_favorite` | `is_favorite` | вычисляется | наличие в `parser_favorite_product` |
| `starred_category_ids` | `starred_category_ids` | вычисляется | assignments favorite categories |
| `vendor_mapped/display` | те же имена | вычисляется service brand mapping | не хранится в `parser_product` |
| `final_price` и `pricing_components` | те же имена | вычисляются service pricing | не хранятся напрямую в `parser_product` |

## Вариант происхождения lineage
`parser_product_origin_variant` хранит lineage по каждому source для aggregated/manual-bound variants:

| Поле | Тип |
|---|---|
| `origin_key` | `string` |
| `product_id` | `int` |
| `source_id` | `int` |
| `source_product_url` | `string` |
| `source_variant_id` | `string \| null` |
| `source_variant_title` | `string \| null` |
| `sku` | `string \| null` |
| `price` | `float \| null` |
| `currency` | `string \| null` |
| `available` | `bool` |
| `payload` | `object` |

## Текущие ограничения
- Ответы backend по продуктам шире, чем raw DB-row, потому что pricing, category, brand и edit views обогащаются на чтении.
- Текущий frontend хранит naming полей backend без изменений.
- Manual products хранятся в `parser_product` с `is_auto_added=false` и могут быть привязаны к external source variants через rows origin-variant.
- Несмотря на legacy-имена колонок `*_asset_ids`, текущий persistence backend хранит URL/token-style values в нескольких image JSON columns:
  - `manual_image_asset_ids` сейчас хранит внутренние URL изображений
  - `hidden_source_image_asset_ids` сейчас хранит URL скрытых source images
  - `manual_image_order` хранит tokens порядка, а не нормализованные numeric foreign keys
