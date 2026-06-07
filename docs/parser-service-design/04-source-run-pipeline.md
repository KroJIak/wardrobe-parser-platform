# Архитектура parser-service: пайплайн выполнения источника

## Область охвата
- Покрывает: `SourceRunService.run(...)`, правила поиска, выполнение стратегий, нормализацию, валидацию, дедупликацию, отслеживание покрытия и сборку `SourceRunReport`.
- Не покрывает: детали реализации отдельных источников сверх того, что ожидает общий pipeline.
- Зависит от: `service/app/services/source_run_service.py`, `service/app/schemas/run_report.py`, `service/app/services/description_text_service.py`, `service/app/services/weight_enrichment_service.py` и контрактов adapter/strategy.

## Точка входа
Выполнение одного источника начинается в:

```text
SourceRunService.run(
  source_key,
  dry_run=False,
  run_id=None,
  candidate_urls=None,
  prefer_candidate_urls=False
)
```

## Шаги pipeline
### 1. Разрешение компонентов среды выполнения
- загрузить `SourceRecord` из `SourceRepository`
- разрешить adapter из `AdapterRegistry`
- вывести допустимые стратегии из `adapter.allowed_strategies`
- создать `RunLogger`

### 2. Валидация source config
Валидация среды выполнения выполняется до начала работы:
- `strategy_sequence`
- `retry_limits`
- `timeouts`
- strategy-specific sections

Невалидная config вызывает `ConfigError`.

### 3. Построение context и отчета
Сервис создает:
- `SourceContext`
- начальный `SourceRunReport(status=in_progress, dry_run=...)`

### 4. Определение режима поиска
`mode` нормализуется из source config:
- поддерживаемые значения: `auto`, `manual`
- неизвестные значения откатываются к `auto`

Поведение поиска:
- `manual` -> использовать только переданные candidate URLs
- `prefer_candidate_urls=true` при наличии candidates -> тоже пропускать discovery
- иначе -> вызвать `adapter.discover_visible_catalog(context)`

Если adapter сигнализирует storefront password gate, `StorefrontBlockedError` преобразуется в `ConfigError("storefront_blocked:...")`.

### 5. Построение базового покрытия
Из обнаруженных URL сервис выводит:
- канонический набор видимых URL
- набор видимых handle
- `visible_catalog_products`

Покрытие отслеживается по handle, если они доступны, иначе по canonical URL.

### 6. Получение weight rules
Если существует `WeightRulesClient`:
- вызвать backend
- получить `WeightRulesPayload`
- при сбое продолжить с `rules=[]`

### 7. Выполнение стратегий по порядку
Для каждого имени стратегии в `strategy_sequence`:
- разрешить стратегию из `StrategyRegistry`
- создать `StrategyAttempt`
- вычислить max retries из `retry_limits`
- построить `StrategyContext`

Специальное правило пропуска:
- если запуск фактически `manual/candidate-only` и candidate URLs отсутствуют, стратегия помечается как успешная no-op attempt

### 8. Повтор выполнения стратегии
Сервис повторяет `strategy.run(context)` до `max_retries + 1` раз.
- все exceptions перехватываются
- финальная строка ошибки записывается в `StrategyAttempt.error` и `report.errors`

### 9. Нормализация сырых элементов
Для каждого raw item стратегии:
- адаптер нормализует его в единую форму продукта
- `vendor` может быть дозаполнен из raw `vendor` или `brand`
- `description` может быть дозаполнено из raw `description` или `body_html`
- текст description нормализуется
- images могут быть дозаполнены из raw `images`
- применяется keyword-based weight enrichment
- URL канонизируется

### 10. Применение duplicate- и dedup-правил
В pipeline есть два разных механизма контроля дубликатов:

#### Дубликаты внутри одной стратегии
- duplicate URL в одном проходе стратегии -> quarantine и ошибка
- duplicate handle в одном проходе стратегии -> quarantine и ошибка

#### Повторы между стратегиями
- повторяющийся URL или handle, уже принятый из предыдущей стратегии -> тихо пропускается

#### Дедупликация похожих продуктов
Если `config.dedup.enabled` равно `true` или отсутствует:
- текущий нормализованный продукт сравнивается с ранее принятыми продуктами
- измерения score:
  - совпадение title
  - совпадение vendor
  - близость цены
  - совпадение handle
- threshold по умолчанию: `0.75`
- элементы выше порога считаются dedup-кандидатами и исключаются

### 11. Валидация нормализованного продукта
Валидацией владеет adapter и возвращает `(ok, reasons)`.

Pipeline также добавляет или корректирует причины:
- `missing_variants`, если отсутствуют source или normalized variants
- `missing_currency`, если на уровне variants не сохранилась валюта

Важное правило вывода:
- верхнеуровневое `currency` удаляется из финального service output
- валюта в текущем контракте вывода ожидается на уровне variant

### 12. Разделение на valid и unavailable
- `ok == true` -> добавить в `valid_products`
- иначе -> добавить snapshot в `unavailable_products` с `unavailable_reasons`

Дополнительные side effects:
- увеличить `aggregated_unavailable_reasons`
- если присутствует `missing_weight`, добавить компактный snapshot в `missing_weight_products`
- отслеживать `weight_source_stats` по `source`, `keyword_rule` и `missing`

### 13. Пересчет покрытия и fallback-кандидатов
После каждой стратегии:
- вычислить текущее `visible_coverage`
- если есть видимые handles, следующие pending candidates — это неразрешенные handles
- иначе следующие pending candidates — это неразрешенные URL
- при `visible_coverage == 1.0` выполнение завершается досрочно

### 14. Финализация отчета
Правила статуса:
- `manual` mode без candidates и без discovered catalog -> `success`
- `visible_coverage == 1.0` -> `success`
- `visible_coverage == 0.0` -> `failed`
- иначе -> `partial`

Отчет финализируется с:
- массивами valid/unavailable products
- `top_valid_products = valid_products[:10]`
- итоговыми счетчиками
- `duration_sec`
- summary покрытия

## Форма SourceRunReport
Основные поля:
- идентичность источника и `adapter_key`
- `dry_run`
- счетчики покрытия
- `status`
- `attempts[]`
- `quarantined_urls[]`
- агрегированные причины unavailable
- строки ошибок
- totals
- valid и unavailable products
- длительность
- snapshots продуктов с отсутствующим весом
- статистика источников веса

## Заметные особенности текущего поведения
- `dry_run` передается в отчет и strategy context, но многие стратегии все равно выполняют реальные сетевые запросы.
- Управление покрытием определяет момент остановки fallback; validation влияет на доступность продукта, а не на то, считается ли продукт распарсенным для покрытия.
- Принятые нормализованные продукты участвуют в dedup-сравнении, даже если в итоге становятся unavailable.
- Pipeline ничего не сохраняет; возвращаемый отчет — это авторитетный результат одного запуска.
