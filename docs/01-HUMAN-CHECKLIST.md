# Чеклист для человека

Этот документ перечисляет ручные входные данные, необходимые для запуска, хостинга и эксплуатации платформы.
Проходите разделы по порядку при подготовке нового окружения.

## Краткая сводка

| Категория | Что покрывает |
|----------|---------------|
| Локальный рантайм | `.env`, порты, локальные Docker-сервисы |
| Учетные данные | admin bootstrap, token secret, учетные данные базы данных |
| Необязательная внешняя зависимость | настройка Bybit pricing worker |
| Хостинг | сервисы Dokploy, домены, volumes, сетевая маршрутизация |
| Операции | резервные копии, постоянные uploads, постоянная конфигурация источников |

## 1. Создать файлы окружения

Создайте корневой `.env` на основе `.env.example`.

Обязательные значения:

| Переменная | Используется в | Назначение |
|----------|----------------|------------|
| `POSTGRES_USER` | postgres, backend, service | имя пользователя БД |
| `POSTGRES_PASSWORD` | postgres, backend, service | пароль БД |
| `POSTGRES_DB` | postgres, backend, service | имя БД |
| `POSTGRES_HOST` | backend, service | хост БД |
| `BACKEND_EXTERNAL_PORT` | local override | локальный порт backend |
| `SERVICE_EXTERNAL_PORT` | local override | локальный порт parser-service |
| `SITE_FRONTEND_EXTERNAL_PORT` | local override | локальный порт site |
| `ADMIN_FRONTEND_EXTERNAL_PORT` | local override | локальный порт admin |
| `POSTGRES_EXTERNAL_PORT` | local override | локальный порт PostgreSQL |
| `DB_ADMIN_EXTERNAL_PORT` | local override | порт Adminer |
| `CORS_ALLOWED_ORIGINS` | backend, service | разрешенные browser origins |
| `ADMIN_SUPERUSER_LOGIN` | backend | стартовый admin bootstrap |
| `ADMIN_SUPERUSER_PASSWORD` | backend | стартовый admin bootstrap |
| `ADMIN_TOKEN_SECRET` | backend | секрет подписи HMAC token |
| `ADMIN_ACCESS_TOKEN_TTL_SEC` | backend | срок жизни access token |
| `ADMIN_REFRESH_TOKEN_TTL_SEC` | backend | срок жизни refresh token |

Рекомендованные значения из локального baseline:

```dotenv
BACKEND_EXTERNAL_PORT=10510
SERVICE_EXTERNAL_PORT=10520
SITE_FRONTEND_EXTERNAL_PORT=10530
ADMIN_FRONTEND_EXTERNAL_PORT=10531
POSTGRES_EXTERNAL_PORT=10540
DB_ADMIN_EXTERNAL_PORT=10550
POSTGRES_HOST=postgres
```

## 2. Подтвердить постоянное хранилище

Платформа требует следующие persistent volumes:

| Volume | Назначение | Сервис |
|--------|------------|--------|
| `postgres_data` | каталог данных PostgreSQL | `postgres` |
| `redis_data` | append-only storage Redis | `redis` |
| `backend_uploads` | product/showcase/admin-uploaded assets | `backend` |

Дополнительно локальная разработка монтирует `./service/config` в parser service,
чтобы `config/sources.json` переживал перезапуски контейнера и оставался редактируемым из рабочей области.

Это монтирование приходит именно из `docker-compose.override.yml`. Базовый `docker-compose.yml` не создает отдельный named volume для parser source registry: без override или отдельного hosted mount сервис работает с копией `config/sources.json`, зашитой в image/контейнерный filesystem.

## 3. Подготовить доступ в admin

Перед первым запуском backend:

1. Установите `ADMIN_SUPERUSER_LOGIN`.
2. Установите `ADMIN_SUPERUSER_PASSWORD`.
3. Установите `ADMIN_TOKEN_SECRET`.

На запуске backend гарантирует наличие superadmin account.
Далее поток входа в admin использует `/api/v1/auth/login` и хранит access/refresh tokens в cookies.

## 4. Настроить входы для необязательного pricing worker

Фоновый pricing worker запускается как `backend-worker`.
Если включено automatic Bybit rate refresh, проверьте эти значения:

| Переменная | Назначение |
|----------|------------|
| `PRICING_BYBIT_RATE_AUTO_ENABLED` | включить периодическое обновление |
| `PRICING_BYBIT_RATE_CACHE_SEC` | длительность кэша |
| `PRICING_BYBIT_RATE_TIMEOUT_SEC` | timeout внешнего запроса |
| `PRICING_BYBIT_FIAT` | fiat market |
| `PRICING_BYBIT_ASSET` | base asset |
| `PRICING_BYBIT_ADS_LIMIT` | лимит объявлений на запрос |
| `PRICING_BYBIT_BUCKET_STEP_USDT` | шаг bucket |
| `PRICING_BYBIT_BUCKET_MAX_USDT` | верхняя граница bucket |
| `PRICING_BYBIT_OUTLIER_MAX_DEVIATION_RATIO` | порог фильтра outlier |
| `PRICING_BYBIT_WORKER_INTERVAL_SEC` | интервал цикла worker |

Если развертывание не использует automatic Bybit-derived rates, отключайте это явно, а не неявно.

## 5. Подготовить конфигурацию источников

Parser service владеет `config/sources.json` как durable source registry file.

Перед эксплуатацией:

1. Убедитесь, что файл существует по пути `service/config/sources.json`.
2. В local baseline убедитесь, что используется `docker-compose.override.yml`, где `./service/config` bind-mount'ится в контейнер.
3. В hosted runtime добавьте отдельный persistent mount для этого пути вручную; базовый compose сам по себе его не создает.
4. Считайте изменения source runtime configuration файловым состоянием parser-service.

Не предполагается, что source configuration parser-service сейчас хранится в PostgreSQL.

## 6. Чеклист локального запуска

Для локального baseline:

1. Заполнить `.env`.
2. Выполнить `docker compose up -d --build`.
3. Убедиться, что `backend-db-init` завершился успешно.
4. Убедиться, что `service-db-init` завершился успешно с документированным no-op сообщением.
5. Проверить endpoints:
   - backend: `http://localhost:${BACKEND_EXTERNAL_PORT}/health`
   - parser service: `http://localhost:${SERVICE_EXTERNAL_PORT}/health`
   - site: `http://localhost:${SITE_FRONTEND_EXTERNAL_PORT}/`
   - admin: `http://localhost:${ADMIN_FRONTEND_EXTERNAL_PORT}/login`
6. Войти в стартовую admin-учетную запись.

## 7. Чеклист настройки Dokploy

Создайте отдельные services для:

| Сервис | Внутренний порт | Примечание |
|--------|-----------------|------------|
| `frontend-site` | `80` | контейнер public site |
| `frontend-admin` | `80` | контейнер admin |
| `backend` | `8000` | API и uploads |
| `service` | `8000` | parser runtime |
| `postgres` | `5432` | только внутренний |
| `redis` | `6379` | только внутренний |

Маршрутизация доменов:

| Домен | Целевой сервис | Внутренний порт |
|--------|----------------|-----------------|
| `antonshell.com` | `frontend-site` | `80` |
| `admin.antonshell.com` | `frontend-admin` | `80` |

## 8. Предварительная проверка

Перед тем как считать окружение готовым, проверьте:

- значения в `.env` существуют и не закоммичены в git
- PostgreSQL и Redis healthy
- `backend-db-init` выполнил `alembic upgrade head`
- `backend` может достучаться до `service` через `SERVICE_BASE_URL`
- `service` может достучаться до `backend` через `BACKEND_BASE_URL`
- `backend_uploads` переживает перезапуски контейнеров
- `service/config/sources.json` переживает перезапуски сервиса парсинга
- вход в admin проходит, а `/api/v1/auth/me` возвращает session с permissions
