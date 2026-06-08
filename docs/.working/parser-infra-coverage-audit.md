# Parser / Infra Coverage Audit

## Что было не так

1. `infra-design/` и `01-HUMAN-CHECKLIST.md` описывали parser source config как просто "долговечный", но не фиксировали важную деталь текущего compose: отдельная persistence для `/app/config` существует только через `docker-compose.override.yml`, а базовый `docker-compose.yml` такого mount не создает.
2. Верхний слой docs не отражал несколько реальных current-state фактов репозитория:
   - корневой репозиторий является orchestration-root с тремя Git submodule;
   - `frontend-site` сейчас уже не общий каталог/showcase runtime, а минимальный отдельный entrypoint;
   - `frontend-admin` держит полный admin/showcase SPA.
3. `parser-service-design/` не проговаривал достаточно явно, что image содержит seed-copy `config/sources.json`, а без mount все PATCH-изменения source registry живут только в writable layer контейнера.
4. `repo-auxiliary/` был прав по общему смыслу, но слишком слабо инвентаризировал реальные root/bootstrap assets и группы `testing/*`.

## Что исправлено

- Обновлены `00-MASTER-PLAN.md`, `02-ARCHITECTURE.md`, `03-architecture-decision.md` под текущую форму orchestration-root, submodules и минимального `site` runtime.
- В `01-HUMAN-CHECKLIST.md` добавлены:
  - `POSTGRES_EXTERNAL_PORT` в таблицу env,
  - явное описание того, что persistence parser source config локально приходит из override,
  - требование отдельного hosted mount для `service/config`.
- В `parser-service-design/` зафиксированы:
  - seed-copy `config/` внутри image,
  - зависимость долговечности source registry от infra mount,
  - фактические счетчики `sources.json` (`27` total, `27` enabled, `26` sync-enabled),
  - отсутствие auth/rate-limit слоя на `/api/v1/sync/*`,
  - асимметрия `cancel`-маршрутов,
- В `infra-design/` выровнены compose/nginx/Dokploy факты:
  - `frontend-site` = минимальный public site,
  - `frontend-admin` = admin/showcase SPA,
  - `/api` proxy остается у обоих frontend-контейнеров,
  - parser source config требует отдельного persistent mount.
- В `repo-auxiliary/` добавлены root bootstrap assets и более детальный inventory `testing/*`.

## Residual Risk

1. Аудит был ограничен write-scope и сознательно не правил `frontend-design/`, `backend-design/`, `api/` и `database-schema/`, даже если верхнеуровневые тексты теперь на них ссылаются чуть точнее, чем раньше.
2. `repo-auxiliary/02-testing-labs-and-diagnostics.md` документирует группы и примеры артефактов, а не буквальный file-by-file каталог всего `testing/`.
3. В parser-service остается известная runtime-аномалия `POST /api/v1/sync/probe/jobs/{job_id}/cancel` для неизвестного `job_id`; в этом проходе она только задокументирована, а не исправлена кодом.
