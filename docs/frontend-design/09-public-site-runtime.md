# Проектирование фронтенда: рантайм публичного сайта

## Охват
- Охватывает: текущий активный `site`-рантайм, его изоляцию от `admin`, минимальный набор файлов и поведение рендера.
- Не охватывает: admin-shell, showcase-маршруты `admin` или backend-каталог.
- Зависит от: `src/site/site-app.tsx`, `src/site/site-home-page.tsx`, `src/site/site.css`, `apps/site/main.tsx`.

## Активный рантайм
Текущая сборка `site` намеренно минималистична.

`SiteApp`:
- устанавливает `document.title = "Anton Shell"`
- рендерит `SiteHomePage`

`SiteHomePage`:
- рендерит `<main className="site-page">`
- показывает ровно одну фразу: `be monki`

## Отсутствующие слои
Текущий `site`-рантайм:
- не создает маршрутизатор
- не создает `LiveDataProvider`
- не использует `authFetch()`
- не использует admin-session helpers
- не рендерит showcase/catalog/product pages

## Минимальный набор исходников
В текущем `src/site/` присутствуют только:
- `site-app.tsx`
- `site-home-page.tsx`
- `site.css`

Ранее существовавшие site-страницы каталога и продукта вынесены из активного `site`-дерева и больше не составляют его runtime.

## Связь с backend
Несмотря на минимальный рендер, `frontend-site` контейнер по-прежнему проксирует `/api/` на backend через nginx.

Следствия:
- browser на `site` host технически может обращаться к `/api/*`
- текущее смонтированное приложение этого не делает

## Изоляция от admin
Текущий `site` изолирован от `admin` в трех смыслах:
- собственный entrypoint сборки
- собственный CSS-файл `src/site/site.css`
- отсутствие imports из `src/shared/live-data-context.tsx`, `src/shared/admin-auth.ts` и admin showcase routes

## Практический итог
- `site` сейчас является отдельным минимальным сайтом, а не урезанной витриной admin-панели.
- user-facing catalog/product/showcase flows продолжают жить на `admin` host.
- единственная общая точка касания с остальной платформой на уровне контейнера `site` — это `/api` proxy.
