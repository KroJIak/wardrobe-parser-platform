# Архитектура parser-service: browser runner и автоматизация

## Область охвата
- Покрывает: browser runner на Node, жизненный цикл Chromium/Xvfb, extension bridge, выбор scenario и то, как browser strategies потребляют runner output.
- Не покрывает: backend ingestion событий или общие детали pipeline одного source-run, уже описанные в других документах.
- Зависит от: `service/browser_runner/*`, `service/app/strategies/shopify_browser_extension.py` и `service/app/strategies/goat_browser_extension.py`.

## Назначение
Browser runner существует для storefront, которые нельзя надежно распарсить через обычные HTTP-эндпоинты. Он упакован в тот же service image и запускается как подпроцесс из Python strategies.

## Модель упаковки
`browser_runner` — это отдельный Node-module со следующими частями:
- entrypoint: `src/index.mjs`
- extension bridge: `src/core/extension-bridge.mjs`
- browser launcher: `src/core/browser-launcher.mjs`
- scenario registry: `src/scenarios/registry.mjs`
- Chrome extension assets: `extension/background.js`, `extension/manifest.json`

Установленные зависимости среды выполнения:
- `ws`
- `fast-xml-parser`

## Интеграция с Python strategy
`ShopifyBrowserExtensionStrategy.run(...)`:
1. валидирует browser-specific source config
2. требует `browser_extension.script_path`
3. строит команду `node ...`
4. пишет runner output во временный JSON file
5. стримит строки stdout в `RunLogger`
6. разбирает итоговый JSON payload
7. преобразует `previews[]` в единые сырые словари продуктов

`GoatBrowserExtensionStrategy` делегирует той же реализации, временно подменяя имя strategy, чтобы логи и diagnostics использовали GOAT namespace.

## Обязательные ключи browser-конфигурации
Текущая browser strategy читает:
- `script_path`
- `scenario_id`
- `export_concurrency`
- `js_sample_size`
- `max_sitemaps`, если он присутствует
- `show_ui`
- `export_mode`
- `export_max_products`
- `max_collection_pages`
- `skip_discovery_for_limited_json_export`
- `prefer_bridge_fetch`

Она также читает валютную информацию из `shopify_currency`, включая необязательный `country_code`.

## Контракт CLI для runner
Python strategy вызывает Node script с флагами, такими как:
- `--base-url`
- `--browser-binary chromium`
- `--export-products true`
- `--export-mode`
- `--export-concurrency`
- `--js-sample-size`
- `--show-ui true|false`
- `--output-json-path`
- необязательные флаги scenario, sitemap, currency и country

## Запуск browser-окружения
`startBrowserEnvironment(...)`:
- автоматически запускает `Xvfb`, когда `show_ui=false`
- задает `DISPLAY`
- запускает Chromium с распакованным расширением
- сразу использует `--no-sandbox` внутри Docker
- вне Docker повторяет запуск с `--no-sandbox`, если обнаружен ранний sandbox failure
- выделяет свежий Chromium profile directory в `/tmp`

Очистка при завершении:
- завершает Chromium
- удаляет временный profile
- завершает `Xvfb`, если он запускался

## Мост к расширению
Bridge — это WebSocket-сервер, слушающий `0.0.0.0`.

Возможности:
- ждать подключения browser extension
- отправлять command messages
- ждать типизированные ответы с timeout
- отклонять все ожидающие команды при закрытии

Runner может переключиться в режим `network_only`, если extension не подключился вовремя.

## Разрешение scenario
`resolveScenario(baseUrl, forcedScenarioId)` выбирает:
- принудительный scenario, если передан `scenario_id`
- иначе первый scenario, для которого `matches(baseUrl)` возвращает `true`

Текущий registry включает:
- `goat-live`
- `dolcevitahub-shopify-sitemap`
- `default-shopify-sitemap`

Если scenario не найден, runner выбрасывает ошибку.

## Контракт выходных данных
Последняя строка stdout runner — это чистый JSON, и та же полезная нагрузка может быть записана в `--output-json-path`.

Выходная полезная нагрузка содержит:
- `base_url`
- `discovery_mode`
- счетчики discovery/fetch
- счетчик HTTP 429
- warnings
- error details
- `previews[]`

Каждый preview содержит:
- `product_url`
- `handle`
- `title`
- `description`
- `vendor`
- `product_type`
- `price`
- `currency`
- `image_urls`
- `available`
- `variants`
- `payload_source = browser_parser`

Python strategy преобразует эту форму preview в более широкую форму raw-product, которую используют adapters.

## Предпосылки среды выполнения
Перед вызовом Node Python strategy проверяет:
- существует ли `node`
- существует ли `chromium`
- существует ли `Xvfb`, когда `show_ui=false`

Отсутствующие бинарники приводят к ошибкам strategy во время выполнения с явными сообщениями `browser_extension_runtime_missing:*`.

## Текущее использование в реестре
- одна текущая конфигурация источника использует `shopify_browser_extension`
- поддержка browser fallback для GOAT реализована в коде и в регистрации factory, но не активна в текущих последовательностях `sources.json`
