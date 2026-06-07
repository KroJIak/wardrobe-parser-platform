# Протокол: `frontend` ↔ `backend`

## Обзор

Этот протокол определяет все browser-to-API взаимодействия, реализованные между submodule `frontend` и submodule `backend`.

| Аспект | Текущая реализация |
|---|---|
| Транспорт | HTTP/1.1 JSON поверх same-origin REST |
| Базовый публичный path | `/api/v1` |
| Browser hosts | `frontend-site` и `frontend-admin` оба отдают static assets на `:80` и проксируют `/api/` на `backend:8000` |
| Поведение в local dev | Vite также проксирует `/api` на backend |
| Активные frontend apps | `admin` является активным operational client; `site` сейчас рендерит placeholder page |
| Dormant frontend surface | `src/site/*` по-прежнему содержит более богатые страницы catalog/product, которые вызывают public backend API, но эти страницы не монтируются текущим `SiteApp` |

Backend является единственным HTTP API, который потребляет frontend. Прямой browser-to-parser-service контракт не реализован.

## Контракт сессии и транспорта

### Модель cookie-сессии

- Frontend использует `credentials: "include"` для аутентифицированных запросов.
- `POST /api/v1/auth/login` и `POST /api/v1/auth/refresh` устанавливают HTTP-only cookies `admin_access_token` и `admin_refresh_token`.
- `GET /api/v1/auth/me` является авторитетной проверкой "текущей сессии".
- `POST /api/v1/auth/logout` очищает обе cookies.
- `authFetch()` один раз повторяет запрос после `401`, вызывая `POST /api/v1/auth/refresh`, кроме самих запросов `/auth/*`.

### Поведение frontend auth

| Поведение frontend | Текущая реализация |
|---|---|
| Отправка login | raw `fetch()` на `/api/v1/auth/login` |
| Защищенные fetches | wrapper `authFetch()` в `src/shared/admin-auth.ts` |
| Ошибка refresh | выставляет `sessionStorage["admin_auth_expired"] = "1"` и диспатчит `admin-auth-expired` |
| Сайт в runtime | текущий `SiteApp` не аутентифицируется |

## Группы взаимодействий

### 1. Auth и управление административными аккаунтами

| Method | Path | Используется frontend | Auth |
|---|---|---|---|
| `POST` | `/api/v1/auth/login` | форма login admin | public |
| `POST` | `/api/v1/auth/refresh` | тихий refresh сессии | refresh cookie |
| `POST` | `/api/v1/auth/logout` | logout admin | cookie при наличии |
| `GET` | `/api/v1/auth/me` | bootstrap admin, проверка permissions, guard сессии | authenticated admin |
| `GET` | `/api/v1/auth/accounts/bootstrap` | секция аккаунтов в admin settings | superadmin |
| `GET` | `/api/v1/auth/accounts/roles` | секция аккаунтов в admin settings | superadmin |
| `POST` | `/api/v1/auth/accounts/roles` | секция аккаунтов в admin settings | superadmin |
| `PATCH` | `/api/v1/auth/accounts/roles/{role_id}` | секция аккаунтов в admin settings | superadmin |
| `DELETE` | `/api/v1/auth/accounts/roles/{role_id}` | секция аккаунтов в admin settings | superadmin |
| `GET` | `/api/v1/auth/accounts/users` | секция аккаунтов в admin settings | superadmin |
| `POST` | `/api/v1/auth/accounts/users` | секция аккаунтов в admin settings | superadmin |
| `PATCH` | `/api/v1/auth/accounts/users/{user_id}` | секция аккаунтов в admin settings | superadmin |
| `PATCH` | `/api/v1/auth/accounts/users/{user_id}/password` | секция аккаунтов в admin settings | superadmin |
| `DELETE` | `/api/v1/auth/accounts/users/{user_id}` | секция аккаунтов в admin settings | superadmin |

Семейства ответов:

- `login` и `refresh` возвращают `token_type`, `access_expires_in`, `refresh_expires_in`.
- `me` возвращает `user_id`, `login`, `role_name`, `is_superuser`, `is_active` и плоский список `permissions`.
- bootstrap аккаунтов возвращает scopes permissions плюс текущие roles и users.

### 2. Управление источниками и orchestration sync

| Method | Path | Используется frontend | Auth |
|---|---|---|---|
| `GET` | `/api/v1/sources` | bootstrap admin, tab источников | `control.sources.read` |
| `PATCH` | `/api/v1/sources/{source_key}/enabled` | tab источников | `control.sources.edit` |
| `PATCH` | `/api/v1/sources/{source_key}/sync-enabled` | tab источников | `control.sources.edit` |
| `PATCH` | `/api/v1/sources/{source_key}/hide-auto-added-products` | tab источников | `control.sources.edit` |
| `PATCH` | `/api/v1/sources/{source_key}/attribute-visibility` | tab источников | `control.sources.edit` |
| `PATCH` | `/api/v1/sources/{source_key}/currency-priority` | tab источников | `control.sources.edit` |
| `PATCH` | `/api/v1/sources/{source_key}/supplier` | tab источников | `control.pricing.edit` |
| `POST` | `/api/v1/jobs` | запуск sync из admin | `control.sources.edit` |
| `GET` | `/api/v1/jobs/latest` | polling и bootstrap страницы | `control.sources.read` |
| `POST` | `/api/v1/jobs/{job_id}/cancel` | отмена sync | `control.sources.edit` |

Важное поведение backend:

- `/sources` является aggregate-ответом. Backend объединяет данные registry источников parser-service с DB-профилями и counters, которыми владеет backend.
- `/jobs` также aggregate. Backend запускает sync job в parser-service, создает собственный aggregate runtime job id, затем опрашивает события parser-service и сохраняет примененный набор результатов в таблицы backend.
- Flow запуска sync во frontend выполняет preflight `GET /jobs/latest` и обрабатывает backend `409` как отдельный conflict path, а не как generic failure

### 3. Products, brand mapping и ручные операции каталога

| Method | Path | Используется frontend | Auth |
|---|---|---|---|
| `GET` | `/api/v1/admin/products` | legacy-список продуктов admin | `control.products.read` |
| `GET` | `/api/v1/admin/products/table` | таблица продуктов admin | `control.products.read` |
| `GET` | `/api/v1/admin/products/table/facets` | таблица продуктов admin | `control.products.read` |
| `GET` | `/api/v1/admin/brand-mapping` | UI mapping designers | `control.designers.read` |
| `PUT` | `/api/v1/admin/brand-mapping` | UI mapping designers | `control.designers.edit` |
| `GET` | `/api/v1/products` | bootstrap admin и dormant site flows | hybrid, см. ниже |
| `GET` | `/api/v1/products/{product_id}` | detail admin и публичная страница продукта | public для detail продукта |
| `PATCH` | `/api/v1/products/{product_id}` | overrides/status продукта admin | `showcase.edit` |
| `GET` | `/api/v1/products/pricing-example` | UI preview pricing | `control.pricing.read` |
| `POST` | `/api/v1/products/upload-image` | flow ручного продукта | `showcase.edit` |
| `POST` | `/api/v1/products/upload-image-by-url` | flow ручного продукта | `showcase.edit` |
| `POST` | `/api/v1/products/preview-by-url` | preview admin по URL | `control.products.edit` |
| `POST` | `/api/v1/products/probe-by-url` | probe admin по URL | `control.products.edit` |
| `GET` | `/api/v1/products/starred-categories/options` | UI продукта admin | `showcase.read` |
| `POST` | `/api/v1/products/manual` | создание ручного продукта | `control.products.edit` |
| `PATCH` | `/api/v1/products/manual/{product_id}` | обновление ручного продукта | `control.products.edit` |
| `DELETE` | `/api/v1/products/manual/{product_id}` | удаление ручного продукта | `control.products.edit` |
| `GET` | `/api/v1/products/images/{image_id}` | публичные и admin-изображения продукта | public |
| `GET` | `/api/v1/products/{product_id}/starred-categories` | UI продукта admin | `showcase.read` |
| `PUT` | `/api/v1/products/{product_id}/starred-categories` | UI продукта admin | `showcase.edit` |

#### Гибридное поведение `/products`

`GET /api/v1/products` не является чистым endpoint, которым владеет только backend:

1. Backend сначала вызывает `forward_service_request(..., path="products")`.
2. Если upstream service отвечает ошибкой, backend откатывается к DB-backed запросу списка продуктов и возвращает `{items, total, limit, offset}`.
3. Для успешных upstream payload списка backend нормализует возвращенные items и обогащает source ids.

Это делает `/products` hybrid read-контрактом, а не single-source контрактом.

Оговорка по ответу `PATCH /api/v1/products/{product_id}`:
- текущий backend возвращает облегченный mutation payload, а не ту же полностью enriched product-shape, что и при свежем чтении catalog/detail
- projection категорий, состояние favorite и поля final pricing в этой ветке ответа могут отсутствовать, быть очищены или понижены

#### Прокси-поверхность продуктов в legacy-стиле

Backend также публикует proxy-routes:

| Method set | Path | Текущее поведение backend |
|---|---|---|
| `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `HEAD` | `/api/v1/products` | проксируется в parser-service `/api/v1/products` |
| `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `HEAD` | `/api/v1/products/{path:path}` | проксируется в parser-service для ненумерических subpaths |

Факты текущего кода:

- frontend все еще вызывает `/api/v1/products/add-by-url`;
- backend проксирует этот запрос в parser-service `/api/v1/products/add-by-url`;
- в inspected коде parser-service опубликованы только routes `/api/v1/sync/*`.

Итак, proxy-поверхность существует в backend и все еще вызывается frontend, но в inspected runtime service не подтверждена соответствующая реализация parser-service.

### 4. Категории и модерация dedup

| Method | Path | Используется frontend | Auth |
|---|---|---|---|
| `GET` | `/api/v1/categories/tree` | tab категорий | `control.categories.read` |
| `POST` | `/api/v1/categories` | tab категорий | `control.categories.edit` |
| `PATCH` | `/api/v1/categories/{category_id}` | tab категорий | `control.categories.edit` |
| `DELETE` | `/api/v1/categories/{category_id}` | tab категорий | `control.categories.edit` |
| `POST` | `/api/v1/categories/{category_id}/keywords` | tab категорий | `control.categories.edit` |
| `DELETE` | `/api/v1/categories/{category_id}/keywords/{keyword}` | tab категорий | `control.categories.edit` |
| `GET` | `/api/v1/categories/{category_id}/manual-products` | tab категорий | `control.categories.read` |
| `GET` | `/api/v1/categories/{category_id}/manual-products/search` | tab категорий | `control.categories.read` |
| `POST` | `/api/v1/categories/{category_id}/manual-products` | tab категорий | `control.categories.edit` |
| `DELETE` | `/api/v1/categories/{category_id}/manual-products/{product_id}` | tab категорий | `control.categories.edit` |
| `GET` | `/api/v1/dedup/candidates` | tab dedup | `control.dedup.read` |
| `POST` | `/api/v1/dedup/merge` | tab dedup | `control.dedup.edit` |
| `POST` | `/api/v1/dedup/reject` | tab dedup | `control.dedup.edit` |
| `POST` | `/api/v1/dedup/combine` | tab dedup | `control.dedup.edit` |
| `GET` | `/api/v1/dedup/decisions` | tab dedup | `control.dedup.read` |
| `POST` | `/api/v1/dedup/undo` | tab dedup | `control.dedup.edit` |

### 5. Pricing, weight rules, перенос настроек и showcase

| Method | Path | Используется frontend | Auth |
|---|---|---|---|
| `GET` | `/api/v1/settings/pricing` | tab pricing | `control.pricing.read` |
| `PATCH` | `/api/v1/settings/pricing` | tab pricing | `control.pricing.edit` |
| `GET` | `/api/v1/settings/admin-ui` | bootstrap admin | `control.settings.read` |
| `PATCH` | `/api/v1/settings/admin-ui` | admin settings | `control.settings.edit` |
| `POST` | `/api/v1/settings/pricing/suppliers` | tab pricing | `control.pricing.edit` |
| `PATCH` | `/api/v1/settings/pricing/suppliers/{supplier_id}` | tab pricing | `control.pricing.edit` |
| `DELETE` | `/api/v1/settings/pricing/suppliers/{supplier_id}` | tab pricing | `control.pricing.edit` |
| `GET` | `/api/v1/settings/weight-rules` | tab веса | `control.weight.read` |
| `GET` | `/api/v1/settings/weight-rules/parser-contract` | admin weight tools | `control.weight.read` |
| `GET` | `/api/v1/settings/weight-rules/missing-products` | tab веса | `control.weight.read` |
| `POST` | `/api/v1/settings/weight-rules` | tab веса | `control.weight.edit` |
| `PATCH` | `/api/v1/settings/weight-rules/{rule_id}` | tab веса | `control.weight.edit` |
| `DELETE` | `/api/v1/settings/weight-rules/{rule_id}` | tab веса | `control.weight.edit` |
| `POST` | `/api/v1/settings/weight-rules/{rule_id}/keywords` | tab веса | `control.weight.edit` |
| `DELETE` | `/api/v1/settings/weight-rules/{rule_id}/keywords/{keyword}` | tab веса | `control.weight.edit` |
| `GET` | `/api/v1/settings/export` | перенос настроек | `control.settings.read` |
| `POST` | `/api/v1/settings/import` | перенос настроек | `control.settings.edit` |
| `POST` | `/api/v1/settings/reset` | перенос настроек | `control.settings.edit` |
| `GET` | `/api/v1/showcase/state` | public и admin | public |
| `GET` | `/api/v1/showcase/hero/image` | public и admin | public |
| `POST` | `/api/v1/showcase/hero/upload` | editor showcase admin | на route нет auth dependency |
| `DELETE` | `/api/v1/showcase/hero` | editor showcase admin | на route нет auth dependency |
| `PATCH` | `/api/v1/showcase/hero` | editor showcase admin | на route нет auth dependency |
| `GET` | `/api/v1/showcase/carousel` | public и admin | public |
| `POST` | `/api/v1/showcase/carousel/upload` | editor showcase admin | на route нет auth dependency |
| `PATCH` | `/api/v1/showcase/carousel/order` | editor showcase admin | на route нет auth dependency |
| `DELETE` | `/api/v1/showcase/carousel/{image_id}` | editor showcase admin | на route нет auth dependency |
| `GET` | `/api/v1/showcase/carousel/{image_id}/image` | public и admin | public |

Frontend использует некоторые showcase mutations как admin-only actions, но inspected router backend не навешивает auth dependencies на эти mutation endpoints.

### 6. Контракт публичного каталога

| Method | Path | Предполагаемый consumer | Auth |
|---|---|---|---|
| `GET` | `/api/v1/catalog/categories/roots` | public site | public |
| `GET` | `/api/v1/catalog/categories/root/{root_slug}` | public site | public |
| `GET` | `/api/v1/catalog/products` | public site | public |
| `GET` | `/api/v1/products/{product_id}` | public site | public |
| `GET` | `/api/v1/products/images/{image_id}` | public site | public |
| `GET` | `/api/v1/showcase/state` | public site | public |
| `GET` | `/api/v1/showcase/hero/image` | public site | public |
| `GET` | `/api/v1/showcase/carousel` | public site | public |
| `GET` | `/api/v1/showcase/carousel/{image_id}/image` | public site | public |

Текущая реальность frontend:

- смонтированное приложение `site` не вызывает эти endpoints и рендерит только `be monki`;
- dormant `src/site/catalog-page.tsx` и связанные файлы все еще вызывают эти public routes через raw `fetch()`.

## Контракт ошибок

Наблюдаемая HTTP-семантика backend:

| Status | Значение в текущем протоколе |
|---|---|
| `200` | успешное чтение |
| `201` | успешное создание там, где это явно объявлено |
| `204` | успешное удаление/logout/обновление пароля |
| `400` | ошибка валидации или business-rule |
| `401` | пользователь не аутентифицирован или токен невалиден/истек |
| `403` | пользователь аутентифицирован, но permission отсутствует |
| `404` | сущность или public asset не найдены |
| `409` | конфликт sync и отдельные integrity-конфликты |
| `429` | превышен login rate-limit |
| `500` | неожиданная ошибка backend |
| `502` | backend завершился ошибкой при вызове parser-service |

Тела ошибок представляют собой JSON-объекты, сосредоточенные вокруг `detail`.

## Сводка data-flow

```text
Browser app
  -> /api/v1/auth/*             bootstrap и refresh сессии
  -> /api/v1/sources            aggregate view источников
  -> /api/v1/jobs*              aggregate sync runtime backend
  -> /api/v1/products*          смешанные backend-owned reads, backend-owned writes и legacy proxy paths
  -> /api/v1/settings*          backend-owned settings и transfer flows
  -> /api/v1/showcase*          public media reads и currently unguarded media mutations

Backend
  -> валидирует cookies / permissions
  -> напрямую обслуживает DB-backed read/write paths
  -> вызывает parser-service там, где контракт делегирован
```
