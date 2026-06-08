# Вспомогательные материалы репозитория

## Назначение

Эта директория документирует поверхности внутри репозитория, которые являются реальной частью рабочей области проекта,
но не входят в обычную deployed runtime topology:

- orchestration-root артефакты вроде `.gitmodules`, `.env.example` и корневого `README.md`
- служебные скрипты
- исследовательские и лабораторные рабочие области
- сохраненные резервные копии базы данных
- инвентарь verification/test

## Граница

- Охватывает: операционные и инженерные артефакты рядом с репозиторием вне основного runtime платформы.
- НЕ охватывает: production request flow, уже описанный в `frontend-design/`, `backend-design/`, `parser-service-design/`, `database-schema/` и `infra-design/`.

## Индекс документов

| # | Файл | Назначение |
|---|------|------------|
| 00 | `00-OVERVIEW.md` | карта домена и порядок чтения |
| 01 | `01-maintenance-scripts-and-backups.md` | служебные скрипты и сохраненные DB dumps |
| 02 | `02-testing-labs-and-diagnostics.md` | дерево `testing`, лабораторные рабочие области и инвентарь проверок |

## Порядок чтения

1. Зафиксируйте, что этот репозиторий — orchestration-root с тремя submodule (`backend`, `frontend`, `service`), а не одна монолитная codebase.
2. Откройте `01-maintenance-scripts-and-backups.md`, если нужно понять mutation-helpers или recovery-helpers, живущие в репозитории.
3. Откройте `02-testing-labs-and-diagnostics.md`, чтобы понять нерuntime validation assets и developer-side diagnostics.
