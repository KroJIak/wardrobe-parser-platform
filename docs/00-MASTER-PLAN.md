# Wardrobe Parser Platform

## Что читать сейчас

Единственный актуальный документ по новой модели данных и админским сценариям:
- `docs/database-redesign-admin/`

Для runtime-правды:
- `frontend/` — витрина и админка
- `backend/` — API, auth, orchestration, DB write/read model
- `service/` — parser-service и source sync runtime

Для окружения:
- `docs/infra-design/`

Для внутренних продуктовых правил:
- `docs/internal/`

Для служебных материалов рядом с репозиторием:
- `docs/repo-auxiliary/`

## Важно

Старые parser-era и pre-redesign документы удалены.  
Если документ противоречит `docs/database-redesign-admin/` или живому коду, источником истины считается:

1. `docs/database-redesign-admin/` — для новой схемы БД и admin-сценариев.
2. Pydantic-схемы, routers и сервисы в коде — для реальных HTTP и runtime-контрактов.

## Порядок чтения

1. `docs/database-redesign-admin/00-INDEX.md`
2. `docs/02-ARCHITECTURE.md`
3. runtime-код нужного модуля: `frontend/`, `backend/` или `service/`
4. `docs/infra-design/`, если вопрос про compose, deployment или networking
