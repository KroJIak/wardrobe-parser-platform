# Модель данных: Weight Rule

## Область действия
Эта модель покрывает weight rules, которыми управляет backend, parser-facing экспорт rule-контрактов и view продуктов с отсутствующим весом.

## Структура weight rule
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `id` | `int` | да | id rule |
| `weight_grams` | `int` | да | соответствующий вес |
| `keywords` | `array<string>` | да | связанные keywords |

## Структура parser-контракта
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `revision` | `string` | да | marker revision export |
| `rules` | `array<parser-weight-rule-item>` | да | rules, пригодные для consumption parser |

`parser-weight-rule-item`:

| Поле | Тип |
|---|---|
| `weight_grams` | `int` |
| `keywords` | `array<string>` |

## Структура продукта без веса
| Поле | Тип | Обязательно |
|---|---|---|
| `id` | `int` | да |
| `title` | `string` | да |
| `url` | `string` | да |
| `source_id` | `int` | да |
| `source_name` | `string` | да |

## Представления по доменам
### `frontend`
- `WeightRule`
- `WeightMissingProduct`

### `backend`
- `WeightRuleResponse`
- `ParserWeightRulesContractResponse`
- `ParserWeightRuleItem`
- request bodies create/update для rule и keyword operations

### `parser-service`
- `WeightRulesPayload`
- dataclass `WeightRule` в `weight_rules_client.py`

### `database`
- `parser_weight_rule`
- `parser_weight_keyword`

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `parser-service` | `database` |
|---|---|---|---|---|
| `keywords` | то же имя | то же имя | lowercased при fetch | отдельные rows в `parser_weight_keyword` |
| `revision` | напрямую не потребляется текущим frontend | response parser contract | `WeightRulesPayload.revision` | не хранится отдельной колонкой |

## Текущие ограничения
- Parser-service читает weight rules только через public contract backend `/api/v1/public/parser-contract/weight-rules`.
- Parser-service деградирует к `revision="unavailable"` и пустым rules при ошибке fetch.
- View products missing-weight выводится backend и не представлено отдельной таблицей.
