# Аутентификация и авторизация

## Область действия
Этот документ определяет текущую модель административной аутентификации, сессий и permissions, которую используют `frontend` и `backend`.

## Компоненты
| Компонент | Расположение | Ответственность |
|---|---|---|
| Router auth | `backend/app/api/v1/auth.py` | login, refresh, logout, текущая сессия, управление superadmin-аккаунтами |
| Реализация токенов | `backend/app/services/auth/admin_auth_service.py` | выпуск токенов, валидация подписи, auth dependencies |
| Ограничение частоты | `backend/app/services/auth/login_rate_limiter.py` | throttling неудачных login через Redis |
| Клиентская обертка frontend | `frontend/src/shared/admin-auth.ts` | аутентифицированный `fetch` на cookies и silent refresh |

## Транспорт сессии
Административная сессия использует две HTTP-only cookies:

| Cookie | Назначение | Источник |
|---|---|---|
| `admin_access_token` | short-lived access token | устанавливается на `/api/v1/auth/login` и `/api/v1/auth/refresh` |
| `admin_refresh_token` | более долгоживущий refresh token | устанавливается на `/api/v1/auth/login` и `/api/v1/auth/refresh` |

Параметры cookies:

- `HttpOnly=true`
- `SameSite=lax`
- `Path=/`
- `Secure=settings.admin_auth_cookie_secure`
- `Max-Age` вычисляется из TTL токена

## Формат токена
Платформа не использует внешнюю JWT-библиотеку. Токены представляют собой кастомные HMAC-подписанные строки в JWT-форме:

`base64url(header).base64url(payload).base64url(signature)`

Поля заголовка:

| Поле | Значение |
|---|---|
| `alg` | `HS256` |
| `typ` | `JWT` |
| `ver` | `2` |

Payload claims:

| Claim | Значение |
|---|---|
| `uid` | id администратора |
| `sub` | login администратора |
| `type` | `access` или `refresh` |
| `iat` | unix timestamp момента выпуска |
| `exp` | unix timestamp истечения |
| `jti` | случайный id токена |

Ключ подписи:

- `settings.admin_token_secret`

## Поток аутентификации backend
### `POST /api/v1/auth/login`
Тело запроса:

```json
{
  "login": "admin",
  "password": "secret"
}
```

Успешный ответ:

```json
{
  "token_type": "bearer",
  "access_expires_in": 3600,
  "refresh_expires_in": 2592000
}
```

Поведение:

1. Проверка rate-limit по IP клиента.
2. Перед поиском credentials гарантируется bootstrap superadmin.
3. Credentials валидируются по `admin_user.password_hash`.
4. Выпускаются access и refresh cookies.

### `POST /api/v1/auth/refresh`
- Читает `admin_refresh_token` из cookie.
- Проверяет тип токена, подпись, срок действия, наличие пользователя, совпадение login пользователя и `is_active`.
- Перевыпускает обе cookies.

### `POST /api/v1/auth/logout`
- Удаляет обе auth cookies.
- Возвращает `204 No Content`.

### `GET /api/v1/auth/me`
Ответ:

```json
{
  "user_id": 1,
  "login": "admin",
  "role_name": "superadmin",
  "is_superuser": true,
  "is_active": true,
  "permissions": ["accounts.edit", "accounts.read"]
}
```

Поведение списка permissions:

- superadmin получает все статические permission keys
- обычный admin получает нормализованные permissions роли

## Поведение frontend-сессии
Основной wrapper: `authFetch()`.

Поведение:

1. Отправляет запрос с `credentials: "include"`.
2. Если ответ не `401`, возвращает его.
3. Если путь запроса начинается с `/api/v1/auth/`, не делает auto-refresh.
4. Иначе вызывает `POST /api/v1/auth/refresh`.
5. При успешном refresh один раз повторяет исходный запрос.
6. При неуспешном refresh выставляет `sessionStorage["admin_auth_expired"]="1"` и диспатчит `admin-auth-expired`.

Дополнительные frontend helpers:

- `checkAdminSessionSilently()` проверяет `/auth/me`, затем при необходимости один раз делает refresh.
- `logoutAdminSession()` вызывает `/auth/logout` и очищает frontend session hints.

## Модель авторизации
Защищенные routes опираются на FastAPI dependencies:

| Dependency | Значение |
|---|---|
| `require_admin_access` | требуется валидный access token |
| `require_superadmin` | у аутентифицированного пользователя должно быть `is_superuser=true` |
| `require_permission("...")` | у аутентифицированного пользователя должен быть конкретный permission, если он не superadmin |

Каталог permissions статический и задокументирован в [data-models/enums.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/data-models/enums.md:1).

## Семантика auth-ошибок
| Ситуация | Status | Шаблон detail |
|---|---|---|
| отсутствует access token | `401` | `Требуется авторизация` |
| malformed token | `401` | detail о невалидном токене |
| неверный тип токена | `401` | `Неверный тип токена` |
| токен истек | `401` | `Токен истёк` |
| пользователь отключен | `401` | `Пользователь отключен` |
| недостаточно прав | `403` | `Недостаточно прав` |
| сработал login rate-limit | `429` | too many attempts |

## Текущие операционные примечания
- Access может передаваться через bearer header или access cookie; frontend использует cookies.
- Flow refresh в текущем frontend работает только через cookies.
- Для стабильной работы auth необходимы явные `ADMIN_TOKEN_SECRET` и env-переменные superadmin.
- Throttling login работает по best-effort: ошибки Redis логируются и не блокируют попытки login.
- Mutation endpoints showcase сейчас существуют без auth dependencies в `showcase.py`; admin UI рассматривает их как admin-операции, но router не обеспечивает эту границу.
