# Модель данных: Showcase State

## Область действия
Эта модель покрывает media-state showcase, используемое публичным сайтом и admin-controls showcase.

## Каноническая структура состояния
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `showcase_hero_image_asset_id` | `int \| null` | нет | id текущего hero asset |
| `showcase_carousel_image_asset_ids` | `array<int>` | да | упорядоченные ids carousel asset |
| `carousel_limit` | `int` | да | жесткий максимум длины carousel |

## Вспомогательные структуры ответа
### Листинг carousel
| Поле | Тип |
|---|---|
| `items` | `array<int>` |
| `limit` | `int` |

### Подтверждения mutation
| Ответ | Структура |
|---|---|
| upload/set hero | `{ ok: bool, image_asset_id: int }` |
| clear hero | `{ ok: bool }` |
| upload carousel | `{ ok: bool, image_asset_id: int, items: array<int> }` |
| reorder/remove carousel | `{ ok: bool, items: array<int> }` |

## Представления по доменам
### `frontend`
- Editor showcase в admin читает/пишет asset ids.
- Публичные consumers используют:
  - `GET /api/v1/showcase/state`
  - `GET /api/v1/showcase/hero/image`
  - `GET /api/v1/showcase/carousel/{image_id}/image`

### `backend`
- `ShowcaseMediaSettingsResponse`
- `ShowcaseHeroSetRequest`
- `ShowcaseCarouselOrderRequest`

### `database`
- IDs хранятся в `admin_ui_settings`:
  - `showcase_hero_image_asset_id`
  - `showcase_carousel_image_asset_ids`
- image files представлены через `image_asset`

## Примечания по mapping
| Каноническое поле | `backend` | `database` |
|---|---|---|
| id hero asset | то же имя поля | `admin_ui_settings.showcase_hero_image_asset_id` |
| ids carousel asset | то же имя поля | JSON `admin_ui_settings.showcase_carousel_image_asset_ids` |
| image lookup | binary route | `image_asset.id -> stored_path` |

## Текущие ограничения
- Uploads принимают `.jpg`, `.jpeg`, `.png`, `.webp`.
- id hero автоматически удаляется из carousel при дублировании.
- Binary image endpoints возвращают cache headers `no-store`.
- Mutation endpoints showcase сейчас не применяют auth dependencies на уровне router.
