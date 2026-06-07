# Модель данных: Brand Mapping

## Область действия
Эта модель покрывает управляемые admin правила нормализации брендов, используемые в read-side enrichment продуктов и в логике designers/categories.

## Структура элемента mapping
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `source_brand` | `string` | да | исходная метка бренда |
| `source_brand_key` | `string` | да | нормализованный уникальный ключ source-brand |
| `target_brand` | `string` | да | целевой канонический бренд |
| `include_in_designers` | `bool` | да | нужно ли показывать в логике designers |

## Структура ответа списка
| Поле | Тип | Описание |
|---|---|---|
| `items` | `array<brand-mapping-item>` | строки mapping |
| `known_targets` | `array<string>` | distinct известных target brands |

## Структура запроса обновления
| Поле | Тип |
|---|---|
| `items` | `array<brand-mapping-item>` |

## Представления по доменам
### `frontend`
- `SettingsTransferBrandMappingEntry` для flows import/export
- admin UI brand mapping потребляет payload list/update напрямую

### `backend`
- `BrandMappingItemResponse`
- `BrandMappingListResponse`
- `BrandMappingUpdateRequest`

### `database`
- `parser_brand_mapping`
  - `source_brand`
  - `source_brand_key`
  - `target_brand`
  - `include_in_designers`
  - timestamps

## Примечания по mapping
| Каноническое поле | Backend | Database |
|---|---|---|
| `source_brand_key` | то же имя | уникальная хранимая колонка |
| `known_targets` | вычисляемый список | не хранится как отдельная структура |

## Текущие ограничения
- Brand mapping применяется во время enrichment продукта в backend, а не во frontend.
- Уникальность `source_brand_key` является опорой persistence.
- Settings transfer включает ту же shape без list-wrapper.
