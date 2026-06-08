# Проектирование фронтенда: настройка проекта

## Охват
- Охватывает: структуру проекта, конфигурацию package, команды сборки, выбор режима Vite, сборку Docker image, рантайм nginx, переменные окружения.
- Не охватывает: поведение маршрутов, логику фич, бизнес-процессы внутри вкладок.
- Зависит от: `frontend/package.json`, `frontend/vite.config.ts`, `frontend/Dockerfile`, `frontend/nginx/nginx.conf`.

## Роль репозитория
Сабмодуль `frontend` представляет собой один репозиторий, который выпускает два deployable статических web-приложения из общей кодовой базы:
- `admin` из `apps/admin`
- `site` из `apps/site`

Для каждого прогона сборки существует один выходной каталог `dist/`. Текущее приложение выбирается режимом Vite при локальной разработке и аргументом `FRONTEND_APP` во время Docker build.

## Структура исходников
| Путь | Ответственность |
|---|---|
| `apps/admin/` | admin HTML-оболочка и bootstrap через `main.tsx` |
| `apps/site/` | site HTML-оболочка и bootstrap через `main.tsx` |
| `src/admin/` | оболочка admin-приложения, showcase routes, feature-tabs, admin-hooks |
| `src/site/` | минимальный отдельный site-runtime: `site-app.tsx`, `site-home-page.tsx`, `site.css` |
| `src/shared/` | общий UI, контейнер состояния, API-helpers, auth-helpers, утилиты форматирования |
| `src/styles.css` | глобальный CSS только для `admin` |
| `src/site/site.css` | отдельный CSS только для `site` |
| `public/` | статические ассеты, копируемые Vite |
| `nginx/` | конфигурация production web-server для контейнера |

## Конфигурация package
Стек рантайма, объявленный в `package.json`, включает:
- React 18 + React DOM 18
- `react-router-dom`
- `lucide-react`
- `katex`
- UI/helper-зависимости, включая `@gravity-ui/uikit`, `class-variance-authority`, `clsx`, `embla-carousel-react`, `radix-ui`, `tailwind-merge`

Инструменты сборки включают:
- Vite 5
- `@vitejs/plugin-react`
- `@tailwindcss/vite`
- Tailwind 4, PostCSS, `tw-animate-css`

Текущий подход к стилям опирается в основном на вручную написанный CSS:
- `admin` использует `src/styles.css`
- `site` использует `src/site/site.css`

Tailwind установлен и подключен к Vite, но текущий feature-код не использует utility-first архитектуру как основной механизм оформления.

## Скрипты
| Команда | Эффект |
|---|---|
| `npm run dev` | запускает Vite в режиме `admin` |
| `npm run dev:admin` | то же, что и `dev` |
| `npm run dev:site` | запускает Vite в режиме `site` |
| `npm run build` | собирает `admin` |
| `npm run build:admin` | собирает `admin` |
| `npm run build:site` | собирает `site` |
| `npm run preview` | запускает Vite preview server |

## Конфигурация Vite
`vite.config.ts` динамически выбирает корень приложения:
- `mode === "site"` -> `apps/site`
- любой другой режим -> `apps/admin`

Общая конфигурация:
- включен React plugin
- включен Tailwind Vite plugin
- aliases:
  - `@` -> `src`
  - `@admin` -> `src/admin`
  - `@shared` -> `src/shared`
  - `@site` -> `src/site`
- output сборки: `dist/`
- dev server: `host: true`, `port: 3000`
- preview: `host: true`, `port: 4173`

## Входы окружения
Активный frontend-код читает только небольшой набор build-переменных:

| Переменная | Используется в | Назначение |
|---|---|---|
| `VITE_LOCAL_API_URL` | `vite.config.ts` | целевой адрес для Vite dev proxy `/api` |
| `VITE_ALLOWED_HOSTS` | `vite.config.ts` | allow-list хостов для preview |
| `FRONTEND_APP` | `Dockerfile` | выбирает target сборки `admin` или `site` |

В browser-коде нет app-level runtime config loader. Базовые API-path заданы относительными путями `/api/v1`.

## Оболочки HTML
`apps/admin/index.html`:
- language `ru`
- статический `<title>Anton Shell Admin</title>`
- монтирует `./main.tsx`

`apps/site/index.html`:
- language `en`
- статический `<title>Anton Shell</title>`
- монтирует `./main.tsx`

Оба shell-файла минималистичны и полагаются на React для управления заголовком документа после монтирования.

## Сетевая схема локальной разработки
Во время локальной разработки с Vite:
- browser-запросы к `/api/*` проксируются на `VITE_LOCAL_API_URL` или `http://localhost:10510`
- это сохраняет same-origin восприятие browser-кода
- в исходных модулях нет отдельной frontend-конфигурации хоста API

## Сборка Docker-образа
Frontend-контейнер представляет собой двухстадийный образ:

1. `node:20-alpine` builder
2. `nginx:alpine` runtime

Поведение сборки:
- копирует весь репозиторий в `/app`
- при возможности переиспользует существующий `node_modules` из build context
- откатывается на `npm ci`, если `node_modules` отсутствует
- запускает ровно одну из команд:
  - `npm run build:admin`
  - `npm run build:site`

Образ среды выполнения:
- копирует `/app/dist` в `/usr/share/nginx/html`
- копирует `nginx/nginx.conf` в дефолтную конфигурацию nginx
- открывает внутренний порт контейнера `80`

## Рантайм nginx
Текущее поведение nginx:
- раздает собранные статические файлы из `/usr/share/nginx/html`
- использует `try_files $uri /index.html` для SPA fallback
- проксирует `/api/` на `http://backend:8000`
- отдает `/health` с plain-text `ok`
- ограничивает размер тела запроса через `client_max_body_size 100m`

Оба контейнера `admin` и `site` используют один и тот же внутренний порт `80`. Маршрутизация доменов выполняется вне контейнера через Docker Compose, Dokploy или внешний reverse proxy.

## Операционные последствия
- Сборочный pipeline учитывает целевое приложение, но репозиторий по-прежнему остается общим по исходникам.
- `admin` и `site` используют общие ассеты из `public/`, но не общую таблицу стилей.
- Поскольку API base задан относительным путем, frontend предполагает same-origin API-доступ как в режиме Vite proxy, так и в режиме nginx.
