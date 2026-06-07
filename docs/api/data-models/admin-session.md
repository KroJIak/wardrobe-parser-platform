# Модель данных: Admin Session

## Область действия
Эта модель покрывает login input, выпуск сессии, поведение refresh и текущую аутентифицированную identity, возвращаемую `/api/v1/auth/*`.

## Запрос login
| Поле | Тип | Обязательно | Ограничения |
|---|---|---|---|
| `login` | `string` | да | `1..128` chars |
| `password` | `string` | да | `1..256` chars |

## Ответ сессии
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `token_type` | `string` | да | всегда `bearer` |
| `access_expires_in` | `int` | да | секунды до истечения access |
| `refresh_expires_in` | `int` | да | секунды до истечения refresh |

## Текущая сессия (`/auth/me`)
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `user_id` | `int` | да | id аутентифицированного admin user |
| `login` | `string` | да | аутентифицированный login |
| `role_name` | `string \| null` | нет | отображаемое имя роли или `superadmin` |
| `is_superuser` | `bool` | да | флаг auth-context |
| `is_active` | `bool` | да | active-состояние пользователя |
| `permissions` | `array<string>` | да | эффективный список permissions |

## Представления по доменам
### `frontend`
- `authFetch()` трактует `401` как истекшую сессию, если только refresh не завершился успешно.
- `checkAdminSessionSilently()` использует `/auth/me` как авторитетную проверку сессии.

### `backend`
- `AdminLoginRequest`
- `AdminSessionResponse`
- `AdminMeResponse`
- claims токена являются внутренними и описаны в [../auth.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/auth.md:1)

### `database`
- Отдельной таблицы сессий в inspected-коде backend нет.
- Валидность сессии stateless, за исключением lookup пользователя и login rate limiting в Redis.

## Примечания по mapping
| Каноническое поле | `frontend` | `backend` | `database` |
|---|---|---|---|
| login request | raw `fetch()` на экране login | `AdminLoginRequest` | проверка credentials по `admin_user` |
| session response | используется только для TTL metadata | `AdminSessionResponse` | нет |
| current identity | хранится только в памяти UI | `AdminMeResponse` | вычисляется из `admin_user` + `admin_role` |

## Текущие ограничения
- Для refresh требуется cookie `admin_refresh_token`.
- Access token может читаться из bearer header или `admin_access_token`.
- Состояние сессии инвалидируется неявно при истечении токена, отключении пользователя, смене login или смене token secret.
