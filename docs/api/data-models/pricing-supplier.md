# Модель данных: Pricing Supplier

## Область действия
Эта модель покрывает строки suppliers и строки shipping-rate, встраиваемые в pricing settings и используемые конфигурацией источников.

## Структура supplier
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `id` | `int` | да | id supplier |
| `key` | `string` | да | внутренний стабильный технический идентификатор supplier |
| `name` | `string` | да | отображаемое имя |
| `category` | `string` | да | см. `enums.md` |
| `parent_supplier_id` | `int \| null` | нет | родитель для alt supplier |
| `alt_position` | `int` | да | порядок alt supplier |
| `rate_currency` | `string` | да | валюта настроенных rates |
| `rates` | `array<supplier-rate>` | да | строки shipping-rate |

### Структура supplier rate
| Поле | Тип | Описание |
|---|---|---|
| `min_kg` | `float` | нижняя включительная граница |
| `max_kg` | `float \| null` | верхняя граница |
| `rub` | `float` | стоимость shipping в RUB |

## Представления по доменам
### `frontend`
- `PricingSupplier`
- `PricingSupplierRate`
- подмножество settings transfer:
  - `SettingsTransferSupplierEntry`
  - `SettingsTransferSupplierRateEntry`

### `backend`
- `PricingSupplierResponse`
- `PricingSupplierRateResponse`
- запросы create/update:
  - `PricingSupplierCreateRequest`
  - `PricingSupplierUpdateRequest`

### `database`
- `parser_supplier`
- `parser_supplier_shipping_rate`

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `database` |
|---|---|---|---|
| `rub` | `rub` | `rub` | `rate_rub` |
| `parent_supplier_id` | то же имя | то же имя | `parent_supplier_id` |
| `category` | то же имя | то же имя | строковая колонка |
| `key` | `key` | `key` | `parser_supplier.key` |

## Текущие ограничения
- backend-ответ нормализует DB `rate_rub` в API-поле `rub`.
- payload supplier в settings transfer использует `parent_supplier_key`, а не `parent_supplier_id`.
- В обычном create-flow `key` не принимается от admin UI: backend сначала создает запись, затем назначает ей `key` по схеме `supplier-{id}`.
- Значения category supplier задокументированы в [enums.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/data-models/enums.md:1).
