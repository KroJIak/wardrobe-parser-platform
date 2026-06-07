# Модель данных: Product Preview

## Область действия
Эта модель покрывает облегченные payload продуктов, используемые до сохранения в каталог или во время ручного редактирования продукта:

- `POST /api/v1/products/preview-by-url`
- `POST /api/v1/products/probe-by-url`
- `POST /api/v1/products/manual`
- `PATCH /api/v1/products/manual/{product_id}`

## Каноническая структура preview
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `id` | `int \| null` | нет | id существующего backend product; `0` или отсутствие для probe |
| `source_id` | `int \| null` | нет | mapped id backend source |
| `source_name` | `string \| null` | нет | отображаемое имя source |
| `status` | `string \| null` | нет | status source или backend |
| `handle` | `string` | да | handle source или fallback, выведенный из URL |
| `title` | `string` | да | title продукта |
| `description` | `string \| null` | нет | description продукта |
| `weight_grams` | `float \| null` | нет | явный или inferred weight |
| `vendor` | `string \| null` | нет | vendor source |
| `product_type` | `string \| null` | нет | тип source |
| `product_url` | `string` | да | канонический URL продукта |
| `price` | `float \| null` | нет | base/effective цена |
| `currency` | `string` | да | отображаемая валюта |
| `buyer_total_price` | `float \| null` | нет | итоговая цена покупателя только для probe |
| `buyer_service_fee` | `float \| null` | нет | service fee только для probe |
| `image_urls` | `array<string>` | да | preview images |
| `variants` | `array<preview-variant>` | нет | доступные preview variants |

### Структура preview variant
| Поле | Тип |
|---|---|
| `title` | `string` |
| `price` | `float \| null` |
| `currency` | `string` |
| `available` | `bool` |
| `inventory_quantity` | `int` |
| `option1/2/3` | `string \| null` |
| `sku` | `string \| null` |

## Пейлоад upsert для ручного продукта
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `title` | `string` | да | manual title |
| `description` | `string \| null` | нет | manual description |
| `vendor` | `string \| null` | нет | manual vendor |
| `product_type` | `string \| null` | нет | manual type |
| `variants` | `array<manual-variant>` | да | требуется как минимум один variant |
| `manual_image_asset_ids` | `array<int>` | да | ids uploaded image asset |
| `weight_grams` | `float \| null` | нет | необязательный manual weight |
| `status` | `string \| null` | нет | `available`, `out_of_stock` или `hidden` |
| `bind_sync` | `bool` | нет | привязать manual product к lineage external source |
| `bind_source_id` | `int \| null` | нет | id origin source при привязке |
| `bind_source_product_url` | `string \| null` | нет | нормализованный origin source URL |

### Структура manual variant
| Поле | Тип |
|---|---|
| `title` | `string` |
| `price` | `float \| null` |
| `currency` | `string` |
| `available` | `bool` |

## Представления по доменам
### `frontend`
- `ProductUrlPreview`
- payload create/update manual в `LiveDataContextValue`

### `backend`
- Ответы preview/probe являются raw `dict[str, Any]`, а не именованными Pydantic response-моделями.
- Requests upsert manual:
  - `CreateManualProductRequest`
  - `UpdateManualProductRequest`

### `parser-service`
- Источник probe приходит из payload `product_batch`, эмитируемых probe jobs.

## Примечания по mapping
| Flow | Поведение |
|---|---|
| preview-by-url | ищет уже сохраненный backend product по нормализованным URL/handle |
| probe-by-url | запускает probe job parser-service и переводит последний item `product_batch` в preview JSON |
| manual create | сохраняет поля preview-like в `parser_product` плюс optional binding origin-variant |
| manual update | переписывает поля manual product и optional bound origin variants |

## Текущие ограничения
- Preview probe является synthetic и может использовать fallback-извлечение handle из URL path.
- Responses preview используют `product_url`, тогда как payload сохраненного продукта использует `url`.
- IDs manual images переводятся backend в URL `/api/v1/products/images/{id}` перед сохранением.
