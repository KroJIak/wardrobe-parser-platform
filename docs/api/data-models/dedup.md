# Модель данных: Dedup

## Область действия
Эта модель покрывает payload review duplicate-detection и сохраненные decisions модератора.

## Кандидат dedup
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `pair_key` | `string` | да | стабильный идентификатор пары |
| `score` | `float` | да | confidence duplicate |
| `reasons` | `array<string>` | да | список объяснений |
| `left` | `parser-product` | да | первый продукт |
| `right` | `parser-product` | да | второй продукт |

Обертка ответа списка:

| Поле | Тип |
|---|---|
| `items` | `array<dedup-candidate>` |
| `total` | `int` |
| `limit` | `int` |
| `offset` | `int` |

## Решение dedup
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `pair_key` | `string` | да | идентификатор пары |
| `action` | `string` | да | текущее действие decision |
| `decided_at` | `datetime \| null` | нет | время decision |
| `can_undo` | `bool` | да | разрешен ли сейчас undo |
| `undo_block_reason` | `string \| null` | нет | пояснение, когда undo заблокирован |
| `left` | `parser-product` | да | snapshot левой стороны |
| `right` | `parser-product` | да | snapshot правой стороны |

Команды решения:

| Команда | Поля |
|---|---|
| merge | `primary_product_id`, `duplicate_product_id` |
| reject | `product_a_id`, `product_b_id` |
| combine | `product_a_id`, `product_b_id` |
| undo | `pair_key` |

## Представления по доменам
### `frontend`
- `DedupCandidate`
- `DedupDecision`

### `backend`
- `DedupCandidateResponse`
- `DedupDecisionResponse`
- request types:
  - `DedupMergeRequest`
  - `DedupRejectRequest`
  - `DedupCombineRequest`
  - `DedupUndoRequest`

### `database`
- `parser_dedup_decision`
  - `pair_key`, `left_product_id`, `right_product_id`, `action`, `merged_into_product_id`, `snapshot_payload`, `restore_payload`, timestamps

## Примечания по mapping
| Каноническое поле | `backend` | `database` |
|---|---|---|
| candidate pair | вычисляется `DedupService` | не хранится |
| decision action | response `action` | `parser_dedup_decision.action` |
| возможность undo | вычисляемое поле | производное от сохраненного decision + текущего состояния каталога |
| payload продуктов left/right | enriched `ProductResponse` | ids продуктов плюс snapshots/payloads |

## Текущие ограничения
- Decisions сохраняются; candidates являются вычисляемыми views.
- Undo опирается на сохраненные `snapshot_payload` и `restore_payload`.
- Actions decision и lifecycle задокументированы в [enums.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/data-models/enums.md:1).
