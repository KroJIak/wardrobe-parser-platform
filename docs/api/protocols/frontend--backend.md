# Протокол: `frontend` ↔ `backend`

## Обзор
Этот протокол определяет все browser-to-API взаимодействия, реализованные между submodule `frontend` и submodule `backend`.

| Аспект | Текущая реализация |
|---|---|
| Транспорт | HTTP/1.1 JSON поверх same-origin REST |
| Базовый публичный path | `/api/v1` |
| Browser hosts | `frontend-site` и `frontend-admin` оба отдают static assets на `:80` и проксируют `/api/` на `backend:8000` |
| Поведение в local dev | Vite проксирует `/api` на backend |
| Активные frontend apps | `admin` является активным operational client и одновременно host-ом для showcase/catalog/product routes; `site` рендерит только страницу `be monki` |

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
| `site` runtime | не аутентифицируется |

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
- `/sources` является aggregate-ответом. Backend объединяет данные registry parser-service с DB-профилями и counters, которыми владеет backend.
- `/jobs` также aggregate. Backend запускает sync job в parser-service, создает собственный aggregate runtime job id, затем опрашивает события parser-service и сохраняет примененный набор результатов в таблицы backend.

### 3. Products, brand mapping и ручные операции каталога
| Method | Path | Используется frontend | Auth |
|---|---|---|---|
| `GET` | `/api/v1/admin/products` | legacy-список продуктов admin | `control.products.read` |
| `GET` | `/api/v1/admin/products/table` | таблица продуктов admin | `control.products.read` |
| `GET` | `/api/v1/admin/products/table/facets` | таблица продуктов admin | `control.products.read` |
| `GET` | `/api/v1/admin/brand-mapping` | UI mapping designers | `control.designers.read` |
| `PUT` | `/api/v1/admin/brand-mapping` | UI mapping designers | `control.designers.edit` |
| `GET` | `/api/v1/products` | bootstrap admin | hybrid, см. ниже |
| `GET` | `/api/v1/products/{product_id}` | detail admin showcase и публичный detail-contract | public |
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
1. backend сначала вызывает `forward_service_request(..., path="products")`;
2. если upstream service отвечает ошибкой, backend откатывается к DB-backed запросу списка продуктов и возвращает `{items, total, limit, offset}`;
3. для успешных upstream payload списка backend нормализует возвращенные items и обогащает source ids.

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
| `GET` | `/api/v1/showcase/state` | admin showcase и внешние public reads | public |
| `GET` | `/api/v1/showcase/hero/image` | admin showcase и внешние public reads | public |
| `POST` | `/api/v1/showcase/hero/upload` | editor showcase admin | на route нет auth dependency |
| `DELETE` | `/api/v1/showcase/hero` | editor showcase admin | на route нет auth dependency |
| `PATCH` | `/api/v1/showcase/hero` | editor showcase admin | на route нет auth dependency |
| `GET` | `/api/v1/showcase/carousel` | admin showcase и внешние public reads | public |
| `POST` | `/api/v1/showcase/carousel/upload` | editor showcase admin | на route нет auth dependency |
| `PATCH` | `/api/v1/showcase/carousel/order` | editor showcase admin | на route нет auth dependency |
| `DELETE` | `/api/v1/showcase/carousel/{image_id}` | editor showcase admin | на route нет auth dependency |
| `GET` | `/api/v1/showcase/carousel/{image_id}/image` | admin showcase и внешние public reads | public |

### 6. Контракт каталога и showcase
| Method | Path | Текущий consumer во frontend | Auth |
|---|---|---|---|
| `GET` | `/api/v1/catalog/categories/roots` | admin showcase | public |
| `GET` | `/api/v1/catalog/categories/root/{root_slug}` | admin showcase | public |
| `GET` | `/api/v1/catalog/products` | admin showcase | public |
| `GET` | `/api/v1/products/{product_id}` | admin showcase product page | public |
| `GET` | `/api/v1/products/images/{image_id}` | admin showcase и публичные image URLs | public |
| `GET` | `/api/v1/showcase/state` | admin showcase | public |
| `GET` | `/api/v1/showcase/hero/image` | admin showcase | public |
| `GET` | `/api/v1/showcase/carousel` | admin showcase | public |
| `GET` | `/api/v1/showcase/carousel/{image_id}/image` | admin showcase | public |

Текущая реальность frontend:
- смонтированное приложение `site` не вызывает эти endpoints и рендерит только `be monki`;
- showcase/catalog/product UI для этих endpoint-ов живет на `admin` host.
