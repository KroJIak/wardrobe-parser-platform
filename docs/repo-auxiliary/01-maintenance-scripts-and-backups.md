# Вспомогательные материалы репозитория: служебные скрипты и резервные копии

## Область применения

- Охватывает: сохраненные служебные скрипты и сохраненные backup artifacts.
- НЕ охватывает: normal runtime migration flow или deployed backup automation.

## Корневые orchestration-артефакты

В корне репозитория лежат файлы, которые не являются runtime-кодом доменов, но задают рабочую форму проекта:

- `.gitmodules` фиксирует, что `backend`, `frontend` и `service` подключены как отдельные Git submodule
- `.env.example` задает локальный baseline для compose-портов и основных переменных окружения
- `README.md` — краткий root-level descriptor orchestration-репозитория

Эти файлы не исполняют бизнес-логику сами по себе, но являются частью фактической bootstrap-поверхности проекта.

## Поверхность служебных скриптов

### `backend/scripts/reset_category_tree.py`

Этот script — реальная поверхность изменения database, а не заметка и не placeholder.

Текущая роль:

- открыть backend DB session
- удалить non-system category state
- пересоздать baseline для root/category
- засеять keywords и canonical tree structure

Операционное следствие:

- script может существенно переписать category state вне normal HTTP admin flows
- любой будущий category refactor должен учитывать этот script как часть project surface

## Сохраненные резервные копии

Сейчас repository включает PostgreSQL dump artifacts в `backups/db/`:

- `wardrobe_pre_reset_20260509-180343.dump`
- `wardrobe_pre_reset_20260509-180355.dump`

Это не часть live runtime, но это часть operational history репозитория.

Следствие для документации:

- backup handling в этом repo не является чисто теоретическим
- checked-in dumps нужно считать recovery/reference artifacts, а не active application inputs

## Текущая граница

- runtime backup priorities и persistence rules по-прежнему документируются в `infra-design/03-operations-and-secrets.md`
- этот файл добавляет факт со стороны репозитория: dumps, orchestration-root bootstrap files и maintenance scripts уже существуют в дереве проекта
