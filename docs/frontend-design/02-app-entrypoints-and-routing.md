# Проектирование фронтенда: точки входа приложений и маршрутизация

## Охват
- Охватывает: `apps/admin`, `apps/site`, React-точки входа, активные деревья маршрутизации, поток защищенных маршрутов, структуры смонтированных страниц.
- Не охватывает: детальные внутренности auth transport или контракты мутаций provider.
- Зависит от: `apps/*/main.tsx`, `src/admin/admin-app.tsx`, `src/site/site-app.tsx`, `src/admin/admin-showcase-layout.tsx`.

## Разделение точек входа
Репозиторий содержит две верхнеуровневые браузерные точки входа:

| Сборка | Файл | Монтируемое приложение | CSS |
|---|---|---|---|
| `admin` | `apps/admin/main.tsx` | `AdminApp` | `src/styles.css` |
| `site` | `apps/site/main.tsx` | `SiteApp` | `src/site/site.css` |

Обе точки входа:
- создают React root через `ReactDOM.createRoot(...)`
- оборачивают приложение в `React.StrictMode`

## Дерево admin-рантайма
`AdminApp` монтирует:
- `BrowserRouter`
- `AdminRoutes`

### Таблица admin-маршрутов
| Путь | Поведение |
|---|---|
| `/` | showcase home внутри `AdminShowcaseLayout` |
| `/catalog` | showcase home внутри `AdminShowcaseLayout` |
| `/catalog/:slug` | showcase category page |
| `/category/:slug` | showcase category page |
| `/product/:id` | showcase product page |
| `/login` | login form |
| `/control` | перенаправляет на `/control/products` |
| `/control/:tab` | admin-shell вкладок |
| `*` | перенаправляет обратно на `/` |

### Поддерживаемые ключи вкладок
Параметр маршрута `:tab` нормализуется по набору:
- `products`
- `dedup`
- `categories`
- `designers`
- `sources`
- `pricing`
- `weight`
- `settings`

Неизвестные или отсутствующие значения вкладок заменяются на `products`.

## Композиция admin-маршрутов
`AdminRoutes` выполняет три задачи на уровне маршрутов:
1. Предварительную проверку сессии через `checkAdminSessionSilently()`
2. Прослушивание редиректа по истечению сессии через `admin-auth-expired`
3. Условное монтирование `LiveDataProvider` для всех маршрутов кроме login

### Поведение guard-слоя
- При первом входе на маршрут `AdminRoutes` блокирует рендеринг с помощью `authChecking`.
- Если проверка сессии не проходит и маршрут не равен `/login`, пользователь перенаправляется на `/login`.
- Если проверка сессии проходит, а пользователь находится на `/login`, он перенаправляется на `/control/products`.

### Граница provider
`LiveDataProvider` оборачивает все admin-маршруты кроме `/login`:
- showcase `/`, `/catalog`, `/category/:slug`, `/product/:id`
- `control`-вкладки

Это означает, что даже user-facing showcase pages на хосте admin работают внутри того же data-provider, что и operational tabs.

## Обертки admin-shell
Дерево admin-маршрутов также включает:
- `RouteTitleSync`
  - `/login` -> `Вход | Anton Shell Admin`
  - все остальные admin-маршруты -> `Anton Shell Admin`
- `RouteTransitionIndicator`
  - временную полоску прогресса при смене `pathname`
- `AdminErrorBoundary`
  - перехватывает ошибки рендера вокруг `AdminPage`

## Модель экранов admin-shell
`/control/:tab` не создает отдельный маршрут на каждую бизнес-фичу. Вместо этого:
- один маршрут рендерит `AdminPage`
- `AdminPage` читает `tab` из параметров маршрутизатора
- `AdminTabContent` переключает feature-вкладки внутри страницы

Это shell на базе вкладок с выбором активной вкладки через route.

## Showcase-слой внутри admin
Маршруты `/`, `/catalog`, `/category/:slug` и `/product/:id` рендерятся через `AdminShowcaseLayout`.

`AdminShowcaseLayout`:
- использует общий `SiteHeader`
- показывает CTA-переход либо в `/control/products`, либо обратно в `/`
- содержит logout action
- рендерит дочерний showcase route в `<Outlet />`

То есть текущая витрина и product pages остаются частью `admin` deployment, а не отдельного `site`.

## Дерево site-рантайма
Активный `SiteApp` сейчас:
- не монтирует `BrowserRouter`
- не монтирует `LiveDataProvider`
- устанавливает `document.title = "Anton Shell"` в `useEffect`
- рендерит `SiteHomePage`

`SiteHomePage` рендерит:

```tsx
<main className="site-page">
  <h1 className="site-page__title">be monki</h1>
</main>
```

В текущем смонтированном `site`-рантайме активные маршруты отсутствуют.

## Практический итог
- `admin` является routed SPA с auth-gate, showcase-слоем и bootstrap-подключением provider.
- `site` представляет собой изолированную немаршрутизируемую страницу.
- Публичные catalog/product URL сейчас живут на `admin` host, а не на `site`.
