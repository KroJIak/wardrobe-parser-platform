# Проектирование фронтенда: admin sources, pricing, weight и settings

## Охват
- Охватывает: вкладку sources, вкладку designers, вкладку pricing, вкладку weight, вкладку settings, showcase media, управление учетными записями и ролями.
- Не охватывает: модерацию продуктов, dedup и редактирование дерева категорий.
- Зависит от: `src/admin/admin-sources-tab.tsx`, `admin-designers-tab.tsx`, `admin-pricing-tab.tsx`, `admin-weight-tab.tsx`, `admin-settings-tab.tsx`, связанных hooks.

## Вкладка Sources
`AdminSourcesTab` является операционной control-surface для поведения runtime на уровне источников.

### Основные возможности
- включение и выключение источника
- включение и исключение источника из sync
- авто-скрытие продуктов, связанных с источником
- переключение видимости description/image для продуктов, пришедших из источника
- настройка периода auto-sync через admin UI settings
- запуск sync для одного источника
- отмена активного sync
- просмотр продуктов, принадлежащих источнику
- открытие ручного редактирования для source-scoped продуктов

### Особые характеристики
- вкладка напрямую читает `/auth/me`, чтобы вычислить permission на редактирование
- внутри нее находится собственная modal-логика и логика загрузки source-products
- она использует `authFetch()` напрямую в feature-коде, а не только через provider-hooks

Следовательно, эта вкладка одновременно частично driven provider-слоем и частично самодостаточна.

## Вкладка Designers
`AdminDesignersTab` вместе с `useAdminBrandMapping()` управляет нормализацией брендов.

### Поток данных
- загружается только тогда, когда активная вкладка равна `designers`
- читает `GET /admin/brand-mapping`
- редактирует строки локально
- сохраняет через `PUT /admin/brand-mapping`

Каждая строка содержит:
- исходный бренд источника
- целевой бренд
- флаг включения в designers

Вкладка также поддерживает список подсказок известных целевых брендов для редактирования в combobox-подобном режиме.

## Вкладка Pricing
`AdminPricingTab` представляет собой экран, разбитый на секции и собранный из нескольких subcomponents.

### Секции
- статус worker-а и диагностика Bybit
- отображение формулы и example product
- основные числовые pricing-поля
- редактор customs threshold
- редактор SVC rule
- редактор tariff/supplier
- настройки pricing/source supplier на уровне отдельных источников

### Хуки среды выполнения
| Hook | Назначение |
|---|---|
| `useAdminPricingRuntime` | предупреждения Bybit, загрузка example product, обработка blocked-state |
| `useAdminSourcePricing` | draft для threshold, draft-состояния source pricing, отложенное сохранение |
| `useAdminPricingSettingsSync` | синхронизация локальных draft-полей из provider settings |
| `useAdminPricingSuppliers` | управление draft-состоянием suppliers и tariffs |
| `useAdminPricingLocalState` | локальное редактируемое состояние вкладки |

### Важное поведение
- несколько настроек сохраняются автоматически после задержки, а не по явной submit-кнопке
- редактирование threshold учитывает три валюты и сохраняется через нормализованные payload
- настройки supplier/promo/buyout на уровне источников сохраняются по отложенным таймерам
- загрузка pricing example отключается, пока исходный курс Bybit еще не установлен

## Вкладка Weight
`AdminWeightTab` отвечает за:
- создание weight rules
- редактирование weight rules с debounce
- назначение keywords для каждого правила
- продукты, у которых отсутствует weight

`useAdminWeightRules()`:
- хранит локальные string-drafts
- отправляет числовые правки спустя `700ms`
- валидирует положительный weight при создании

Таблица продуктов без веса:
- ссылается на продукты через `/product/:id?from=admin`
- использует и `IntersectionObserver`, и fallback на scroll threshold для дозагрузки строк

## Вкладка Settings
`AdminSettingsTab` объединяет четыре разные области настроек:
- общие настройки storefront
- showcase media
- export/import/reset
- учетные записи и роли

### Общие настройки storefront
`AdminSettingsGeneralSection` редактирует `adminUiSettings`, включая storefront thresholds, связанные с designers.

### Медиа витрины
`useAdminShowcase()` управляет:
- загрузкой и удалением hero image
- загрузкой изображений в carousel
- порядком элементов carousel через state drag/drop
- удалением элементов carousel

Загрузка выполняется в два шага:
1. загрузить файл ассета
2. сохранить получившийся список `image_asset_id` в admin UI settings через showcase endpoints

### Экспорт / импорт / сброс
`useAdminSettingsTransfer()` управляет browser-side file interactions:
- export создает JSON blob и скачивает `settings-export-YYYY-MM-DD.json`
- import читает локальный JSON-файл и отправляет его обратно
- reset использует локальное состояние подтверждения перед вызовом backend endpoint-а сброса

### Учетные записи и роли
`AdminSettingsAccountsSection` является полноценной feature-областью внутри вкладки settings.

Она поддерживает:
- bootstrap-загрузку scopes, roles и users
- создание, обновление и удаление ролей
- создание пользователя
- активацию и деактивацию пользователя
- flows сброса и изменения пароля

На практике этот раздел доступен только тогда, когда текущий пользователь является superuser.

## Общий операционный паттерн
Во всех этих вкладках общий frontend-паттерн выглядит так:
- лениво загружать provider-data при открытии вкладки
- хранить редактируемые drafts локально как строки, массивы и map-структуры
- сохранять через debounced- или явные действия
- показывать shell-toast-уведомления и для успеха, и для ошибок

## Роль в admin-приложении
Эти вкладки образуют поверхность операционной конфигурации продукта:
- `sources` управляет участием источников в ingestion и поведением источников
- `designers` нормализует идентичность брендов
- `pricing` управляет коммерческой логикой расчета
- `weight` поставляет эвристики для недостающих физических метаданных
- `settings` управляет storefront/media/config export и администрированием учетных записей
