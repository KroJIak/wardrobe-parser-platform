# Архитектура Backend: Аутентификация и RBAC

## Область
- Покрывает: admin authentication, token model, поведение cookies, permission checks, roles/users, bootstrap superadmin, throttling login.
- Не покрывает: бизнес-правила product/category/settings, кроме случаев, где auth их ограничивает.
- Зависит от: `01-project-setup.md`.

## Поверхность аутентификации
Admin auth реализован через:

- router: `app/api/v1/auth.py`
- token/dependency logic: `app/services/auth/admin_auth_service.py`
- account management: `app/services/auth/admin_accounts_service.py`
- password hashing: `app/services/auth/passwords.py`
- permission catalog: `app/services/auth/permissions.py`
- rate limiting: `app/services/auth/login_rate_limiter.py`

Публичные routes showcase и catalog этот стек auth не используют.

## Модель session
Backend не использует внешнюю JWT-библиотеку или внешнего identity provider. Он реализует custom HMAC-signed JWT-like token format.

### Форма token
Закодированный payload содержит:

- `uid` - numeric id admin user
- `sub` - login
- `type` - `access` или `refresh`
- `iat` - issued-at timestamp
- `exp` - expiry timestamp
- `jti` - random token id

Поля header:

- `alg = HS256`
- `typ = JWT`
- `ver = 2`

Signature строится через `HMAC-SHA256` над `header_b64.payload_b64` с использованием `ADMIN_TOKEN_SECRET`.

### Транспорт
Admin access может поступать из:

- `Authorization: Bearer <token>`
- cookie `admin_access_token`

Refresh использует cookie `admin_refresh_token`.

Backend устанавливает обе cookies со свойствами:

- `httponly = true`
- `samesite = lax`
- `secure = ADMIN_AUTH_COOKIE_SECURE`
- `path = /`

## Эндпоинты аутентификации
`/api/v1/auth` публикует:

| Endpoint | Назначение | Auth |
|---|---|---|
| `POST /login` | валидация credentials, выдача cookies | public |
| `POST /refresh` | rotation пары session из refresh cookie | refresh cookie required |
| `POST /logout` | очистка cookies | public |
| `GET /me` | текущий admin context | `require_admin_access` |
| `GET /accounts/bootstrap` | bootstrap payload со scopes, roles и users | `require_superadmin` |
| `GET/POST/PATCH/DELETE /accounts/roles...` | CRUD ролей | `require_superadmin` |
| `GET/POST/PATCH/DELETE /accounts/users...` | CRUD пользователей | `require_superadmin` |
| `PATCH /accounts/users/{user_id}/password` | сброс пароля | `require_superadmin` |

`/auth/me` возвращает normalized permissions. Superadmin получает полный отсортированный catalog permissions.

## Модель permissions
Permissions представляют собой статические string scopes, объявленные в `services/auth/permissions.py`.

Текущие scopes:

| Ключ | Read | Edit |
|---|---|---|
| `showcase` | `showcase.read` | `showcase.edit` |
| `control.sources` | `control.sources.read` | `control.sources.edit` |
| `control.products` | `control.products.read` | `control.products.edit` |
| `control.dedup` | `control.dedup.read` | `control.dedup.edit` |
| `control.categories` | `control.categories.read` | `control.categories.edit` |
| `control.designers` | `control.designers.read` | `control.designers.edit` |
| `control.pricing` | `control.pricing.read` | `control.pricing.edit` |
| `control.weight` | `control.weight.read` | `control.weight.edit` |
| `control.settings` | `control.settings.read` | `control.settings.edit` |
| `accounts` | `accounts.read` | `accounts.edit` |

### Хелперы принудительного контроля
- `require_admin_access`
- `require_superadmin`
- `require_permission(permission)`

`AdminAuthContext.has_permission()` автоматически выдает все permissions superadmin-пользователям.

## Модель данных
Persistent сущности RBAC:

- `AdminRole`
- `AdminUser`

Permissions роли хранятся как list-like payload и нормализуются через `normalize_permission_list()`.

Поведенческие правила:

- inactive users не могут пройти authentication;
- superadmin не зависит от строки role;
- non-superusers наследуют permissions только от назначенной им role;
- неизвестные строки permissions отклоняются на этапе schema-validation.

## Начальное создание суперпользователя
Backend bootstrap'ит системного superadmin из environment на startup и повторно во время проверки credentials.

`ensure_superadmin_user()` гарантирует, что:

- настроенный login существует;
- пользователь активен;
- у пользователя выставлен `is_superuser = true`;
- сохраненный password hash соответствует `ADMIN_SUPERUSER_PASSWORD`.

Операционное следствие: значения environment являются source of truth для bootstrap superadmin. Изменение env credentials может тихо повторно синхронизировать сохраненный пароль при следующем startup или during login verification.

## Обработка паролей
Пароли хешируются с помощью PBKDF2-SHA256 через `services/auth/passwords.py`.

Правила account service, которые важно учитывать:

- имена roles и logins должны быть уникальны;
- последнего active superadmin нельзя удалить;
- superadmin не может удалить самого себя;
- superadmin не может отключить самого себя;
- назначение role для superadmin принадлежит системе и остается `None`.

## Ограничение частоты login
Throttling login основан на Redis и привязан к client host.

Текущие константы:

- окно: `300` seconds
- максимальное число failed attempts: `10`
- формат Redis key: `auth:login:attempts:{client_key}`

Поведение при сбоях:

- ошибки Redis не блокируют login; backend логирует их и продолжает;
- rate limit проверяется только на `/auth/login`;
- успешный login явно не очищает счетчик ошибок.

## Важные caveats текущего состояния
Эти особенности являются частью реализованной системы и важны для docs/operations:

- отсутствует token revocation store; access остается валидным до истечения срока действия, если состояние user не изменилось;
- refresh rotation завязана на cookies и при этом остается stateless с точки зрения server;
- `logout` только очищает cookies, но не инвалидирует ранее выданные bearer tokens;
- backend использует custom token implementation, поэтому стандартные JWT middleware и introspection tools не применяются автоматически;
- mutation endpoints showcase в `showcase.py` сейчас не используют `require_permission(...)`, хотя похожие product/showcase mutations в `products.py` используют.

## Сводка route-to-permission
Большинство admin routers используют dependency-based permission checks:

- `sources.py`: `control.sources.read/edit`, плюс `control.pricing.edit` для patch supplier
- `jobs.py`: `control.sources.read/edit`
- `products.py`: `control.products.read/edit`, `control.pricing.read`, `control.designers.read/edit`, `showcase.read/edit`
- `categories.py`: `control.categories.read/edit`
- `dedup.py`: `control.dedup.read/edit`
- `settings.py`: `control.pricing.*`, `control.weight.*`, `control.settings.*`

Это mapping dependencies и есть реальная граница access control; отдельный mount admin app отсутствует.
