# Модель данных: Pricing Settings

## Область действия
Эта модель покрывает глобальную конфигурацию формулы pricing, возвращаемую `/api/v1/settings/pricing`.

## Каноническая структура
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `markup_multiplier` | `float` | да | базовый multiplier markup |
| `weight_tolerance` | `float` | да | коэффициент tolerance веса |
| `promo_factor` | `float` | да | глобальный promo factor |
| `customs_threshold_eur` | `float` | да | customs threshold |
| `customs_threshold_currency` | `string` | да | валюта threshold |
| `customs_duty_rate` | `float` | да | ставка customs duty |
| `bybit_usdt_to_rub` | `float` | да | effective rate конверсии Bybit |
| `bybit_extra_rub` | `float` | да | дополнительный RUB к rate Bybit |
| `eur_to_usd_rate` | `float` | да | fallback rate EUR → USD |
| `gbp_to_usd_rate` | `float` | да | fallback rate GBP → USD |
| `jpy_to_usd_rate` | `float` | да | fallback rate JPY → USD |
| `final_rounding_mode` | `string` | да | см. `enums.md` |
| `payment_fee_rate` | `float` | да | комиссия платежа |
| `customs_processing_rate` | `float` | да | ставка customs processing |
| `customs_fixed_rub` | `float` | да | фиксированное значение customs в RUB |
| `shipping_alt_threshold_eur` | `float` | да | threshold для alt shipping |
| `tax_rate` | `float` | да | tax rate |
| `dedup_only_available_products` | `bool` | да | сохраненный флаг настройки для фильтрации dedup; текущая runtime-генерация candidates все еще фактически ведет себя как available-only независимо от этого флага |
| `show_product_description` | `bool` | да | toggle description для public/admin |
| `svc_rules` | `array<object>` | да | rules SVC |
| `insurance_rules` | `array<object>` | да | rules insurance |
| `service_fee_rules` | `array<object>` | да | rules service fee |
| `shipping_rules` | `object` | да | вложенные shipping tables country/mode |
| `bybit_rate_status` | `string` | да | health worker Bybit |
| `bybit_rate_warning` | `string \| null` | нет | текст warning Bybit |
| `bybit_bucket_step_usdt` | `int` | да | шаг bucket |
| `bybit_bucket_max_usdt` | `int` | да | максимум bucket |
| `bybit_bucket_rates` | `array<object>` | да | кешированные buckets rate |
| `bybit_worker_auto_enabled` | `bool` | да | флаг worker |
| `bybit_worker_interval_sec` | `int` | да | интервал worker |
| `bybit_last_updated_at` | `datetime \| null` | нет | последнее обновление worker |
| `bybit_last_error` | `string \| null` | нет | последняя ошибка worker |
| `suppliers` | `array<pricing-supplier>` | да | graph suppliers |
| `formula_latex` | `string` | да | отрендеренная формула |
| `formula_lines` | `array<string>` | да | human-readable steps формулы |
| `formula_legend` | `array<object>` | да | legend символов |

## Представления по доменам
### `frontend`
- `PricingSettings`

### `backend`
- `PricingSettingsResponse`
- patch input: `PricingSettingsUpdateRequest`

### `database`
- `parser_pricing_settings`

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `database` |
|---|---|---|---|
| `suppliers` | inline nested array | собранный response | joined из `parser_supplier` и rows rate |
| `formula_*` | те же имена | вычисляется service pricing | не сохраняется в таблице |
| `bybit_rate_*` | те же имена | собирается из provider/runtime | частично сохраняется (`bybit_bucket_rates`, `bybit_last_*`) |
| `shipping_rules` | nested object | та же shape | JSON-column |

## Текущие ограничения
- Этот response шире, чем сохраненная singleton-row, потому что включает runtime-состояние worker и derived text формулы.
- `usd_to_rub` и `eur_to_rub` существуют в DB-model, но не входят в exposed response shape.
- Subgraph suppliers задокументирован отдельно в [pricing-supplier.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/data-models/pricing-supplier.md:1).
