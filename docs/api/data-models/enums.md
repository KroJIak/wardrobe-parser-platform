# Общие enums и state machines

## Ключи permissions
| Ключ scope | Permission чтения | Permission изменения |
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

## Статус источника
`SourceStatus` parser-service:

| Значение | Смысл |
|---|---|
| `active` | источник здоров и включен |
| `disabled` | источник отключен |
| `error` | ошибка конфигурации/runtime источника |
| `auth_required` | источник требует аутентификации |

## Статусы продукта
### Статус source product в parser-service
| Значение | Смысл |
|---|---|
| `available` | доступен в источнике |
| `out_of_stock` | недоступен, но все еще присутствует в listing |
| `unavailable` | невалидный или недоступный продукт |

### Статус curated product в backend
| Значение | Смысл |
|---|---|
| `available` | видим и в наличии |
| `out_of_stock` | видим, но недоступен |
| `hidden` | намеренно скрыт из каталога |
| `unavailable` | состояние недоступности/невалидности в источнике |

## Статус source run
| Значение | Смысл |
|---|---|
| `pending` | run зарегистрирован, но не запущен |
| `in_progress` | run выполняется |
| `success` | вся необходимая работа завершилась успешно |
| `partial` | часть данных получена при частичной ошибке |
| `failed` | terminal failure |
| `cancelled` | отменен оператором/runtime |

## Статус aggregate sync job
Наблюдается одновременно в aggregate runtime backend и ответах parser-service:

| Значение | Смысл |
|---|---|
| `queued` | aggregate job backend создан, но еще не полностью запущен |
| `in_progress` | выполняется |
| `completed` | успешное terminal-state, используемое parser-service/backend |
| `failed` | terminal-state ошибки |
| `cancelled` | terminal-state отмены |
| `password_protected` | frontend-only mapped status backend, когда ошибка источника связана с паролем |

## Коды sync stage
`SyncStageCode` parser-service:

| Значение | Смысл |
|---|---|
| `source_prepare` | инициализация источника |
| `discover_products` | сбор URL продуктов |
| `discover_done` | discovery завершен |
| `fetch_start` | начата фаза fetch |
| `fetch_progress` | fetch выполняется |
| `fetch_skip` | один продукт был пропущен |
| `export_products` | экспорт нормализованных продуктов |
| `strategy_run` | выполнение шага strategy |
| `source_done` | источник завершился успешно |
| `source_failed` | источник завершился ошибкой |
| `job_done` | job завершилась успешно |
| `job_failed` | job завершилась ошибкой |
| `job_cancelled` | job отменена |

## Категория supplier
| Значение | Смысл |
|---|---|
| `main` | основной supplier |
| `alt` | альтернативный supplier |

## Режим финального округления
| Значение | Смысл |
|---|---|
| `none` | финального округления нет |
| `unit` | округление до единиц |
| `ten` | округление до десятков |
| `hundred` | округление до сотен |
| `thousand` | округление до тысяч |

## Метод валюты
| Значение | Смысл |
|---|---|
| `priority_list` | взять первую доступную валюту из configured list |
| `locked_param_currency` | принудительно использовать configured param currency |
| `locked_no_currency` | принудительно использовать locked currency без param lookup |

## Область действия keyword категории
| Значение | Смысл |
|---|---|
| `local` | generic category keyword |
| `title` | keyword только для title |
| `status` | keyword, основанный на status |

## Действия dedup
| Значение | Смысл |
|---|---|
| `merge` | duplicate объединен в primary product |
| `reject` | пара явно отклонена как duplicate |
| `combine` | продукты объединены в один результат |

## Представление по доменам
| Домен | Представление |
|---|---|
| `frontend` | string unions или plain `string` fields в рукописных типах |
| `backend` | string literals, `Literal[...]`, SQLAlchemy enum/text columns |
| `parser-service` | Python `Enum` classes для source/run/stage statuses |
| `database` | PostgreSQL enum для status продукта; text/string columns в остальных местах |

## Машины состояний
### Админская сессия
| Из | В | Триггер | Владелец |
|---|---|---|---|
| unauthenticated | authenticated | успешный `/auth/login` | backend + frontend |
| authenticated | refreshed | `/auth/refresh` | backend + frontend |
| authenticated | expired | истечение или инвалидация токена | backend |
| authenticated/refreshed | logged_out | `/auth/logout` | backend + frontend |

### Запуск источника
| Из | В | Триггер | Владелец |
|---|---|---|---|
| `pending` | `in_progress` | запущено выполнение run | parser-service |
| `in_progress` | `success` | вся работа завершилась успешно | parser-service |
| `in_progress` | `partial` | частичный output при recoverable failure | parser-service |
| `in_progress` | `failed` | terminal error | parser-service |
| `pending/in_progress` | `cancelled` | запрос cancel | parser-service |

### Агрегированная задача синхронизации
| Из | В | Триггер | Владелец |
|---|---|---|---|
| `queued` | `in_progress` | backend опросил активную service job | backend |
| `in_progress` | `completed` | terminal success service + завершен ingest backend | backend |
| `in_progress` | `failed` | ошибка service/backend | backend |
| `queued/in_progress` | `cancelled` | запрос cancel | backend + parser-service |

### Жизненный цикл продукта
| Из | В | Триггер | Владелец |
|---|---|---|---|
| `available` | `out_of_stock` | изменение доступности из source/manual | backend |
| `available/out_of_stock` | `hidden` | политика moderator/source auto-hide | backend |
| `hidden` | `available/out_of_stock` | явный unhide или восстановление derived status | backend |
| любой | `unavailable` | invalidation/unavailable state в source | backend |

### Решение дедупликации
| Из | В | Триггер | Владелец |
|---|---|---|---|
| candidate | `merge` | действие merge модератора | backend |
| candidate | `reject` | действие reject модератора | backend |
| candidate | `combine` | действие combine модератора | backend |
| decided | candidate | действие undo, если разрешено | backend |
