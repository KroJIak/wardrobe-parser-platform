# Проектирование фронтенда: auth и поток сессии

## Охват
- Охватывает: admin login, silent refresh, logout, сигнализацию об истечении сессии, проверки защищенных маршрутов, чтение permission.
- Не охватывает: детали реализации backend-token или схему хранения RBAC.
- Зависит от: `src/shared/admin-auth.ts`, `src/admin/admin-app.tsx`, `src/shared/use-showcase-edit-permission.ts`, `src/admin/admin-settings-accounts-section.tsx`, `src/admin/admin-showcase-layout.tsx`.

## Поверхность auth
В активном runtime auth-слой frontend-а используется только для `admin`. Он опирается на:
- относительный API base `"/api/v1"`
- cookie-based transport через `credentials: "include"`
- refresh сессии при `401`

Ключевые константы:
- `API_BASE = "/api/v1"`
- `ADMIN_AUTH_EXPIRED_FLAG = "admin_auth_expired"`
- `ADMIN_AUTH_EXPIRED_EVENT = "admin-auth-expired"`

## Жизненный цикл сессии
```text
Unauthenticated
  -> POST /auth/login
Authenticated
  -> GET /auth/me
Expired access token
  -> authFetch() sees 401
  -> POST /auth/refresh
Refreshed
  -> retry original request
Refresh failure
  -> mark session expired
  -> emit admin-auth-expired
  -> redirect to /login?reason=expired
Logged out
  -> POST /auth/logout
```

## Поток входа
`AdminLoginRoute` реализует экран входа.

Поведение:
- поля формы: `login`, `password`
- отправка выполняется через raw `fetch()`, а не через `authFetch()`
- запрос:
  - `POST /api/v1/auth/login`
  - `Content-Type: application/json`
  - body `{ login, password }`
- при успехе:
  - очищается подсказка об истекшей сессии
  - выполняется переход на `/control/products`
- при ошибке:
  - выполняется попытка прочитать `{ detail }` из backend JSON
  - fallback-сообщение: `Неверный логин или пароль`

## Первичная проверка сессии
Перед рендерингом всех admin-маршрутов кроме login `AdminRoutes` вызывает `checkAdminSessionSilently()`.

`checkAdminSessionSilently()`:
1. делает `GET /auth/me`
2. если ответ `200`, сессия валидна
3. если ответ `401`, выполняет `POST /auth/refresh`
4. если refresh успешен, повторно делает `GET /auth/me`
5. иначе возвращает `false`

Пока эта проверка выполняется, `AdminRoutes` рендерит `null`.

## Обертка для аутентифицированных запросов
`authFetch()` является центральным helper-ом для аутентифицированных запросов.

Правила:
- всегда отправляет `credentials: "include"`
- если ответ не `401`, возвращает его без изменений
- если URL запроса начинается с `/api/v1/auth/`, refresh не выполняется
- во всех остальных случаях:
  1. выполняется `POST /auth/refresh`
  2. если refresh успешен, исходный запрос повторяется один раз
  3. если refresh неуспешен, сессия помечается как истекшая и выбрасывается browser-event

Refresh-вызовы дедуплицируются через module-scope переменную `refreshInFlight`.

## Сигнализация об истечении сессии
Когда refresh завершается ошибкой:
- `sessionStorage["admin_auth_expired"] = "1"`
- в `window` dispatch-ится `CustomEvent("admin-auth-expired")`

`AdminRoutes` слушает это событие и перенаправляет активные admin-маршруты на:
- `/login?reason=expired`

После этого `AdminLoginRoute`:
- проверяет `reason=expired`
- читает flag из `sessionStorage`
- показывает toast `Ваша сессия истекла. Войдите снова.`
- затем очищает этот flag

## Поток выхода
`logoutAdminSession()`:
- выполняет `POST /auth/logout`
- в блоке `finally` всегда очищает локальные session-hints

Он используется из:
- logout-кнопки `AdminPage`
- logout action в `AdminShowcaseLayout`

`site` не использует logout flow и не вызывает admin-auth helpers.

## Чтение permission
Frontend читает эффективные permission двумя способами.

### 1. Permission на редактирование showcase
`useShowcaseEditPermission()`:
- вызывает `GET /auth/me`
- трактует `is_superuser` как полный доступ
- иначе проверяет наличие `showcase.edit`
- кэширует булево значение на уровне module scope, включая отрицательные результаты

Операционное следствие:
- временный сбой fetch или неавторизованный ответ может оставить в кэше значение `false` до конца жизни страницы
- hook не выполняет автоматический retry после заполнения этого отрицательного кэша на уровне module scope

Этот hook импортируется в admin showcase flows.

### 2. Permission на settings/accounts и редактирование sources
Отдельные admin-области запрашивают `/auth/me` напрямую:
- `AdminSourcesTab` проверяет `control.sources.edit` и `control.settings.edit`
- `AdminSettingsAccountsSection` загружает `me` и поднимает управление учетными записями только для superuser

## Граница защиты маршрутов
Защищено только routed admin-приложение. `site` не имеет auth-gate и не зависит от admin-сессии.

## Практические последствия
- Обработка сессии централизована и согласована для большинства аутентифицированных запросов.
- Login по-прежнему использует raw `fetch()`, потому что не должен рекурсивно входить в поток refresh.
- Проверки permission существуют и в общих hooks, и в feature-local логике.
- Auth-слой реализован как поведение browser-session, а не как глобальный app store.
