# Модель данных: Admin Account

## Область действия
Эта модель покрывает RBAC-данные, публикуемые через `/api/v1/auth/accounts/*`: административные роли, административных пользователей и bootstrap payloads для экрана аккаунтов.

## Каноническая структура роли
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `id` | `int` | да | primary key роли |
| `name` | `string` | да | уникальное имя роли |
| `description` | `string \| null` | нет | свободное описание роли |
| `permissions` | `array<string>` | да | нормализованные permission keys |
| `created_at` | `datetime` | да | timestamp создания |
| `updated_at` | `datetime` | да | timestamp обновления |

## Каноническая структура пользователя
| Поле | Тип | Обязательно | Описание |
|---|---|---|---|
| `id` | `int` | да | primary key пользователя |
| `login` | `string` | да | уникальный login |
| `is_active` | `bool` | да | доступность аккаунта |
| `is_superuser` | `bool` | да | отключает проверки permissions роли |
| `role_id` | `int \| null` | нет | id связанной роли |
| `role_name` | `string \| null` | нет | денормализованное имя роли для UI |
| `permissions` | `array<string>` | да | эффективный список permissions |
| `created_at` | `datetime` | да | timestamp создания |
| `updated_at` | `datetime` | да | timestamp обновления |

## Начальный пейлоад
`GET /api/v1/auth/accounts/bootstrap` возвращает:

| Поле | Тип | Описание |
|---|---|---|
| `scopes` | `array<permission-scope>` | статический каталог scopes с `key`, `read`, `edit` |
| `roles` | `array<role>` | текущие roles |
| `users` | `array<user>` | текущие users |

## Представления по доменам
### `frontend`
- UI административных аккаунтов потребляет backend JSON напрямую.
- В inspected frontend нет выделенного shared-файла типа `AdminUser`; payload аккаунтов обрабатываются в admin-specific views.

### `backend`
- Schemas: `AdminRoleResponse`, `AdminUserResponse`, `AdminAccountsBootstrapResponse`
- Create/update requests:
  - role: `name`, `description`, `permissions`
  - user create: `login`, `password`, `role_id`, `is_active`
  - user update: `login`, `role_id`, `is_active`
  - password update: `password`

### `database`
- `admin_role`
  - `id`, `name`, `description`, `permissions JSONB`, `created_at`, `updated_at`
- `admin_user`
  - `id`, `login`, `password_hash`, `is_active`, `is_superuser`, `role_id`, `created_at`, `updated_at`

## Примечания по mapping
| Каноническое поле | `backend` JSON | `database` |
|---|---|---|
| `permissions` | массив строк | `admin_role.permissions` JSONB |
| `role_name` | вычисляется из joined role | не хранится в `admin_user` |
| `permissions` у пользователя | эффективный список, собираемый при чтении | производное от роли или полного каталога для superadmin |

## Текущие ограничения
- Permission keys роли должны принадлежать статическому каталогу.
- Повторяющиеся permission keys удаляются на этапе валидации.
- Пароли пользователей никогда не возвращаются API и хранятся только как `password_hash`.
