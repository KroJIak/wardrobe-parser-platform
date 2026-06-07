# Архитектура Backend: Фоновые Процессы Выполнения и Внешние Интеграции

## Область
- Покрывает: поведение фонового worker-процесса, использование Redis, исходящие HTTP-интеграции, storage uploads, поверхности runtime-ошибок.
- Не покрывает: полную топологию развертывания или детальное владение схемой.
- Зависит от: `01-project-setup.md`, `04-sync-and-source-orchestration.md`, `07-pricing-weight-and-settings.md`.

## Фоновый worker
Compose запускает отдельный container backend:

```text
python -m app.workers.bybit_rate_worker
```

Этот worker совмещает два цикла:

1. периодический refresh Bybit через `PricingSettingsService.get_settings(refresh_bybit=True)`
2. планирование auto-sync с использованием `AdminUiSettings` и `run_sync_all_enabled_sources(...)`

### Поведение auto-sync
Worker:

- обеспечивает существование `AdminUiSettings(id=1)`;
- читает `auto_sync_period_minutes`;
- использует `auto_sync_next_run_at` как checkpoint расписания;
- запускает aggregate sync backend с `triggered_by="auto"`;
- помечает status как `scheduled`, `started`, `busy` или `error`;
- при конфликте `409` повторяет попытку через `30` секунд;
- при общей ошибке записывает error и повторяет попытку через `60` секунд.

Это означает, что orchestration auto-sync связана с логикой aggregate job backend, а не делегирована напрямую parser-service.

## Использование Redis
Единственная явная интеграция Redis, найденная в runtime backend, - это rate limiting login.

Характеристики:

- нет использования queue Celery/RQ;
- нет distributed job state или использования pub/sub в inspected code backend;
- сбои Redis degrade gracefully и логируются.

## Внешние HTTP-интеграции
Текущие исходящие интеграции включают:

| Target | Для чего используется | Путь client |
|---|---|---|
| parser-service | список sources, sync jobs, events, probes, compatibility proxying | `requests` в routers/services |
| Bybit P2P | reference buckets FX / pricing | pricing service + worker |
| Frankfurter | дополнительная поддержка currency conversion | pricing service |
| произвольные remote image URLs | import image manual product по URL | `urllib` в `products.py` |

### Прокси-клиент service
`services/proxy/service_api_proxy.py`:

- пересобирает target URL под `${SERVICE_BASE_URL}/api/v1/...`;
- пересылает большинство headers, кроме hop-by-hop headers;
- использует configurable connect/read timeouts;
- возвращает body/status/header set upstream почти без изменений.

### Клиенты source/service
`sources.py` и `jobs.py` также выполняют direct calls `requests`, а не используют общую typed client abstraction.

## Загрузка в хранилище
Backend сохраняет files в local filesystem container и индексирует их в `ImageAsset`.

Текущие roots uploads:

- images showcase: `/app/uploads/showcase`
- images manual product: `/app/uploads/products`

Поведение:

- перед сохранением изображения проверяются через Pillow;
- сохраненный path записывается в DB;
- далее runtime отдает files через `FileResponse`.

Это делает local volume persistence обязательным для непрерывности media.

## Обработка runtime-ошибок
Наблюдаемые паттерны:

- недоступность service обычно отдается как `502 Bad Gateway`;
- некоторые admin paths settings/read логируют exceptions и возвращают fallback empty payloads;
- цикл worker ловит broad exceptions, чтобы процесс оставался живым;
- ошибки fetch/upload images возвращают `400` с human-readable message;
- cancel sync выполняется как best-effort и может проглатывать failures upstream.

Система предпочитает непрерывность UI и выживаемость long-running worker строгому fail-fast поведению.

## Логирование и diagnostics
Логирование присутствует, но в основном module-local, а не unified structured logging.

Примеры:

- worker логирует результаты refresh Bybit и scheduling auto-sync;
- endpoints settings и weight contract логируют failures перед возвратом fallback;
- runtime jobs логирует exceptions sync/runtime.

Ни один inspected code не задает глобальный request id, correlation id или стандарт structured JSON logging.

## Важные текущие ограничения
- Active polling sync живет в daemon threads, запущенных backend-процессом.
- Внешние HTTP calls синхронны и могут напрямую связывать latency request с поведением remote systems.
- Uploads и throttling auth делают backend более stateful, чем чистый stateless API process.
- Compose передает env vars, связанные с images, но settings backend сейчас их игнорируют, поэтому часть предполагаемых runtime knobs нефункциональна с точки зрения config backend.
