# Frontend Coverage Audit

## Что было не так
- `docs/frontend-design` описывали showcase/catalog/product как спящий или site-ориентированный слой в `src/site/*`, хотя реальный active runtime находится в `src/admin/*` и монтируется `AdminApp`.
- Документация по routing утверждала, что `admin` не обслуживает `/product/:id` и что `/` редиректит в login/control flow. По коду это уже не так: `admin` держит `/`, `/catalog`, `/category/:slug`, `/product/:id`, `/login`, `/control/:tab`.
- Документация по entrypoints и styling считала, что обе сборки импортируют `src/styles.css`. По коду `site` импортирует `src/site/site.css`, а `src/styles.css` принадлежит `admin`-bundle.
- Документация по public runtime ссылалась на несуществующие `src/site/layout.tsx`, `catalog-page.tsx`, `product-page.tsx` и другие пути, которых в текущем дереве уже нет.
- Несколько файлов описывали showcase permission/logout как часть "спящего public site", хотя эти flows реально используются на admin-hosted showcase routes.

## Что исправлено
- Переписаны overview/setup/routing/public-runtime/styling разделы так, чтобы они отражали текущий split `frontend-admin` и `frontend-site`.
- Зафиксировано, что `site` сейчас минимален и рендерит только `be monki`.
- Зафиксировано, что showcase/catalog/product routes активны в `admin`-приложении и работают через `AdminShowcaseLayout` и `LiveDataProvider`.
- Уточнены реальные entrypoints, route table, auth guard boundary и поведение общего `/api` proxy в Vite и nginx.
- Обновлены references в docs по shared types/transformers, auth и data-access на актуальные admin/shared файлы.
- Уточнены product links в admin docs: они ведут на `/product/:id?from=admin`, а этот маршрут обслуживается самим `AdminApp`.

## Residual risk
- Вне разрешенного write-scope остались документы и файлы, которые могут по-прежнему содержать старые assumptions, например `frontend/README.md`.
- `src/styles.css` все еще содержит селекторы старого placeholder runtime (`.site-placeholder-shell`), которые сейчас не используются отдельной `site`-сборкой; документация это фиксирует, но код не менялся.
- `LiveDataProvider` по-прежнему различает route kind `admin`/`site` по `pathname`, и showcase routes внутри `AdminApp` идут по ветке `site`; документация теперь отражает это, но сама архитектурная асимметрия остается.
