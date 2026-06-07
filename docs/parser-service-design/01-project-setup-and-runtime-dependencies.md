# Архитектура parser-service: настройка проекта и зависимости среды выполнения

## Область охвата
- Покрывает: запуск приложения, раскладку пакетов, настройки окружения, содержимое Docker image и зависимости среды выполнения, нужные Python- и browser-based стратегиям.
- Не покрывает: ключи source-specific config, поведение sync routes и правила нормализации продуктов.
- Зависит от: `service/app/main.py`, `service/app/core/app_factory.py`, `service/app/core/config.py`, `service/Dockerfile`, `service/requirements.txt` и `service/browser_runner/package.json`.

## Инициализация приложения
- Точка входа модуля: `app/main.py`.
- Фабрика приложения: `app/core/app_factory.py:create_app()`.
- HTTP-фреймворк: FastAPI.
- Корень API: `APIRouter(prefix='/api/v1')` из `app/api/v1/__init__.py`.
- Маршрут проверки здоровья: `GET /health` возвращает `{"status": "ok"}`.

### Поведение на старте
- Логирование настраивается через `logging.basicConfig(...)` в момент создания приложения.
- `CORS` middleware устанавливается всегда.
- Все API-маршруты подключаются сразу; в проверенном коде сервиса нет стартовой фазы инициализации базы или прогрева кэша.

## Настройки окружения
`app/core/config.py` определяет небольшую активную поверхность настроек:

| Настройка | Значение по умолчанию | Для чего используется |
|---|---|---|
| `service_name` | `wardrobe-parser-service-v2` | Заголовок FastAPI |
| `cors_allowed_origins` | `*` | `CORSMiddleware.allow_origins` |
| `backend_base_url` | `http://backend:8000` | Запросы weight-rules к backend |

Дополнительные env-переменные среды выполнения, замеченные вне `Settings`:

| Переменная | Кто читает | Назначение |
|---|---|---|
| `SOURCES_CONFIG_PATH` | `SourceRepository` | Необязательная подмена пути к `config/sources.json` |
| `DATABASE_URL` | только compose/среда выполнения | Присутствует в окружении и зависимостях, но не используется активным проверенным runtime-кодом |

## Структура каталогов
```text
service/
  app/
    api/v1/                 HTTP-маршруты sync
    core/                   app factory, settings, exceptions
    domain/                 общие enum
    repositories/           файловый реестр источников
    schemas/                run reports, sync contract, stage codes
    services/               оркестрация и вспомогательные сервисы
    adapters/               source-specific discovery/normalization/validation
    strategies/             extraction mechanisms
  browser_runner/           Node runtime для browser-based strategies
  config/sources.json       изменяемый реестр источников и parser config
  Dockerfile
  requirements.txt
```

## Поверхность Python-зависимостей
`requirements.txt` устанавливает:

| Семейство пакетов | Роль в текущем коде |
|---|---|
| `fastapi`, `uvicorn[standard]` | HTTP-приложение и ASGI-сервер |
| `pydantic`, `pydantic-settings` | settings и модели ответов |
| `requests`, `beautifulsoup4` | HTTP-запросы к storefront и HTML parsing |
| `python-multipart` | доступен для разбора HTTP form, но не является центральным для проверенных sync routes |
| `sqlalchemy`, `psycopg2-binary`, `alembic` | установлены, но не задействованы активным runtime path |
| `pytest` | зависимость для тестов, попадающая в контекст сборки образа |

## Содержимое Docker image
`service/Dockerfile` собирается от `python:3.12-slim` и устанавливает:

| Слой | Устанавливаемые элементы | Зачем они нужны |
|---|---|---|
| Debian packages | `curl`, `ca-certificates` | базовые сетевые утилиты |
| Node runtime | `nodejs`, `npm` | выполнение browser runner |
| Browser runtime | `chromium`, `xvfb` | browser-extension strategies |
| Python app | `pip install -r requirements.txt` | FastAPI service и parser runtime |
| Browser runner app | `npm ci --omit=dev` внутри `/app/browser_runner` | Node-helper для browser-based strategies |

Команда контейнера:

```text
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Активные зависимости среды выполнения по возможностям
### Обычный HTTP-parsing
- Python runtime
- `requests`
- `BeautifulSoup`
- исходящий доступ в интернет к storefront

### Резервный browser-parsing
- Node.js
- бинарник Chromium, доступный как `chromium`
- `Xvfb`, когда `show_ui=false`
- зависимости `browser_runner`: `ws` и `fast-xml-parser`
- browser extension assets из `browser_runner/extension/*`

### Зависимость от backend для обогащения
- исходящий HTTP-доступ к `backend_base_url`
- backend public route `/api/v1/public/parser-contract/weight-rules`

## Предположения по CORS и сети
- CORS origins приходят строкой, разделенной запятыми, и по умолчанию равны wildcard `*`.
- Сервис предполагает достижимость backend внутри одной сети по имени контейнера `backend`.
- В текущих settings не определены service-auth secret, API key или конфигурация mTLS.

## Упакованные, но не авторитетные зависимости
Модуль включает database-oriented пакеты и часто запускается с `DATABASE_URL`, но в проверенном runtime-коде не создает sessions, models или migrations. В текущей реализации эти зависимости латентные, а не авторитетные.

## Операционные последствия
- Browser-based parsing находится в той же зоне отказа контейнера, что и FastAPI app.
- Развертываемый image тяжелее чистого Python worker, потому что поставляет Node, Chromium и Xvfb.
- Отсутствие бинарника `chromium`, `node` или `Xvfb` ломает browser-extension strategies во время выполнения, а не на этапе старта контейнера.
