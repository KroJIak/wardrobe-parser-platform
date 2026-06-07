# Аудит покрытия backend-документацией

## 1. Сводка покрытия

Общее покрытие сильное. Текущий набор `docs/backend-design`, `docs/api`, `docs/database-schema` и `docs/infra-design` уже фиксирует основную форму backend:

- app factory, startup hooks, health surface и filtering OpenAPI
- admin auth и RBAC
- владение shared PostgreSQL schema со стороны backend
- source merge logic и aggregate sync orchestration поверх `service`
- public catalog, admin catalog, showcase и manual product flows
- background worker, Redis limiter, uploads, Docker/Compose runtime

Оставшиеся проблемы — это не широкие пропущенные разделы. Они сосредоточены в небольшом числе мест, где docs:

- существенно приукрашивают то, что backend реально возвращает или сохраняет;
- сглаживают важные runtime-оговорки в общие формулировки;
- опускают системное поведение, которое меняет операционные ожидания.

Уровень уверенности после аудита: высокий для основной backend-surface, средний для нескольких глубоких edge-case в больших файлах вроде `products.py`, `jobs.py` и `settings_transfer_service.py`.

## 2. Наблюдения по убыванию важности

### High: ответ `PATCH /api/v1/products/{product_id}` задокументирован как recomputed product payload, но код возвращает легкий partial payload

Влияние:
- Любой, кто использует docs как источник контракта, будет ожидать, что ответ patch-route эквивалентен свежему enriched product read.
- Реальный ответ намеренно обнуляет или опускает большие части read-model, что может ломать предположения UI/client при рефакторинге или cleanup контрактов.

Code references:
- [backend/app/api/v1/products.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/api/v1/products.py:2600) строки 2600-2669 делают commit mutation, а затем строят облегченный ответ.
- В этом ответе `internal_category_*` очищены, `starred_category_ids` равен `[]`, `is_favorite` равен `False`, `final_price` равен `None`, а `pricing_components.reason` становится `status-only-patch`.

Doc references:
- [docs/backend-design/05-product-catalog-and-public-showcase.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/backend-design/05-product-catalog-and-public-showcase.md:113) строки 113-124 говорят, что route "returns a recomputed payload".

Оценка:
- Это существенное расхождение между контрактом и документацией, а не stylistic gap.

Docs need changes:
- Yes.
- Docs должны явно говорить, что endpoint возвращает lightweight payload-подтверждение mutation, а не тот же fully enriched shape, что и catalog/detail reads.

### High: image-related JSON columns в `parser_product` задокументированы как хранение asset-id, но текущий backend сохраняет там URL/token strings

Влияние:
- Это затрагивает truth на уровне базы, планирование миграций и любой будущий cleanup/refactor media-handling.
- Текущие schema docs подразумевают numeric asset references, в то время как реализация сохраняет сериализованные image URL и ordering tokens.

Code references:
- [backend/app/models/parser_entities.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/models/parser_entities.py:69) строки 69-78 определяют generic JSON columns; на уровне БД тип не закрепляет ids.
- [backend/app/api/v1/products.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/api/v1/products.py:2558) строки 2558-2560 записывают `hidden_source_image_asset_ids`, `manual_image_asset_ids` и `manual_image_order` из нормализованных URL/token payload.
- [backend/app/api/v1/products.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/api/v1/products.py:2965) строки 2965-2966 сохраняют manual image URL и токены `m:{url}` при manual create.
- [backend/app/api/v1/products.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/api/v1/products.py:3098) строки 3098-3099 делают то же при manual update.

Doc references:
- [docs/database-schema/01-parser-catalog-core.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/database-schema/01-parser-catalog-core.md:58) строка 58 и строки 65-67 описывают эти поля как persisted media ids / asset-id style fields.
- [docs/api/data-models/parser-product.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/data-models/parser-product.md:98) строка 98 ссылается на `manual_image_*` и `hidden_source_image_asset_ids` в общем виде, но не уточняет, что current persistence использует URL/token payload, а не numeric ids.

Оценка:
- Это один из самых важных оставшихся truth-gap в backend docs.

Docs need changes:
- Yes.
- Database и API docs должны описывать фактическое persisted representation:
  - `manual_image_asset_ids` сейчас хранит internal image URL;
  - `hidden_source_image_asset_ids` сейчас хранит hidden source image URL;
  - `manual_image_order` хранит ordering tokens вида `m:/api/v1/products/images/{id}`.

### Medium: docs по settings transfer/reset завышают scope и пропускают важные правила частичности

Влияние:
- Операторы могут решить, что `/api/v1/settings/reset` — это выбираемый или полный cross-service reset.
- В реальности reset является full-only, heavily DB-oriented и не сбрасывает source config parser-service.
- Import/export синхронизирует service-backed source fields только когда live service source можно сопоставить по host.

Code references:
- [backend/app/api/v1/settings.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/api/v1/settings.py:148) `POST /settings/reset` не принимает body и всегда вызывает `reset_all()`.
- [backend/app/services/settings/settings_transfer_service.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/settings/settings_transfer_service.py:353) строки 353-413 показывают поведение reset:
  - удаление rows pricing/suppliers/admin UI;
  - reset только backend `ParserSource` flags и supplier bindings;
  - очистка weight rules, category keyword/manual/index state и brand mappings;
  - reset source parser-service не происходит.
- [backend/app/services/settings/settings_transfer_service.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/settings/settings_transfer_service.py:427) строки 427-446 ограничивают `auto_sync_period_minutes` до `>= 60` во время import.
- [backend/app/services/settings/settings_transfer_service.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/settings/settings_transfer_service.py:508) строки 508-584 patch-ят source settings parser-service только когда live service source совпадает по нормализованному host.

Doc references:
- [docs/backend-design/07-pricing-weight-and-settings.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/backend-design/07-pricing-weight-and-settings.md:97) строки 97-106 описывают transfer/reset слишком общо.
- [docs/backend-design/07-pricing-weight-and-settings.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/backend-design/07-pricing-weight-and-settings.md:27) строка 27 говорит, что `POST /settings/reset` сбрасывает "selected settings domain state", но endpoint не принимает selector payload.
- [docs/api/data-models/settings-transfer.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/data-models/settings-transfer.md:4) строки 4-19 и 84-87 описывают scope transfer, но не объясняют host-matched patching service, full-only semantics reset или clamp `auto_sync_period_minutes` при import.

Оценка:
- Высокоуровневая область задокументирована, но операционно важная механика все еще недоописана.

Docs need changes:
- Yes.
- Нужно задокументировать, что:
  - reset в текущем API является только полным;
  - reset затрагивает DB-state, которым владеет backend, но не возвращает source config parser-service к defaults;
  - import source зависит от live host matching между backend и service;
  - imported auto-sync period нормализуется к минимуму 60 минут.

### Medium: docs по категориям пропускают правила auto-generation/protection ветки designers

Влияние:
- Category tree не является полностью ручным.
- `CategoryTreeService` активно поддерживает защищенную ветку designers, производную от brand mappings и admin UI settings.
- Это меняет ожидания от category edits, keyword edits и формы ветвей перед рефакторингом.

Code references:
- [backend/app/services/catalog/category_tree_service.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/catalog/category_tree_service.py:113) строки 113-145 реализуют cadence sync designers и читают `designers_min_products` / `designers_exclude_store_vendors`.
- [backend/app/services/catalog/category_tree_service.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/catalog/category_tree_service.py:393) строки 393-444 автоматически синхронизируют designers branch при `get_category_tree()`.
- [backend/app/services/catalog/category_tree_service.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/catalog/category_tree_service.py:414) строки 414-455 блокируют keyword edits и child creation внутри system branches вроде fallback/designers.

Doc references:
- [docs/backend-design/06-categories-dedup-and-merchandising.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/backend-design/06-categories-dedup-and-merchandising.md:8) строки 8-51 описывают domain category и index behavior, но не покрывают regeneration designers branch или protection system branches.

Оценка:
- Docs достаточно хорошо описывают category CRUD и indexing, но пропускают одну из самых opinionated частей текущего поведения category.

Docs need changes:
- Yes.
- Нужно добавить текущие правила designers branch:
  - derived branch root `Дизайнеры`;
  - триггеры auto-sync по интервалу, brand-mapping signature и `designers_min_products`;
  - влияние `designers_exclude_store_vendors`;
  - ограничения protected-system-branch на keywords и child creation.

### Medium: docs по sync-job пропускают два неочевидных runtime coercion и завышают обязательность create-request

Влияние:
- Aggregate sync status не является прямым passthrough из parser-service.
- Recovery после restart и обработка password-gate меняют terminal semantics, которые видит admin UI.
- Документированный create request подразумевает обязательные поля, которые backend реально посылает только при наличии данных.

Code references:
- [backend/app/api/v1/jobs.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/api/v1/jobs.py:524) строки 524-539 преобразуют persisted `queued`/`in_progress` rows в `failed`, ставят `current_stage = "Прервано из-за перезапуска backend"` и `error_message = "backend_restart_interrupted_job"`.
- [backend/app/api/v1/jobs.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/api/v1/jobs.py:1542) строки 1542-1549 переписывают некоторые terminal aggregate jobs со статуса `failed` в `completed`, когда все failures связаны с password gate.
- [backend/app/api/v1/jobs.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/api/v1/jobs.py:1635) строки 1635-1654 показывают, что backend включает `sources` и `candidate_urls_by_source` только когда они действительно присутствуют.

Doc references:
- [docs/backend-design/04-sync-and-source-orchestration.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/backend-design/04-sync-and-source-orchestration.md:145) строки 145-154 упоминают startup recovery, но не точные failure sentinel values.
- [docs/backend-design/04-sync-and-source-orchestration.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/backend-design/04-sync-and-source-orchestration.md:102) строки 102-114 описывают start flow, но не фиксируют, что `sources` и `candidate_urls_by_source` в реальном outbound payload опциональны.
- [docs/api/data-models/sync-job.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/data-models/sync-job.md:6) строки 6-12 помечают `sources` и `candidate_urls_by_source` как required.

Оценка:
- Docs объясняют orchestration loop, но не часть самых неожиданных правил отображения state.

Docs need changes:
- Yes.
- Docs по sync должны явно говорить, что:
  - startup recovery записывает backend-local interruption sentinel;
  - password-gated sources могут сделать service-side failure видимым как backend `completed` aggregate result;
  - `sources` и `candidate_urls_by_source` опциональны в create request.

### Low: конфигурация dedup и runtime-behavior описаны только частично

Влияние:
- Backend config docs показывают семейство `DEDUP_*`, а pricing docs показывают `dedup_only_available_products`, но реальное runtime-поведение более конкретно.
- Это важно, если следующий рефакторинг должен сохранить или сознательно изменить dedup-semantics.

Code references:
- [backend/app/core/config.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/core/config.py:27) строки 27-38 определяют полную tuning-surface dedup.
- [backend/app/services/moderation/dedup_service.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/moderation/dedup_service.py:533) строки 533-545 жестко ограничивают candidate generation доступными продуктами.
- [backend/app/services/moderation/dedup_service.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/moderation/dedup_service.py:546) строки 546-594 применяют caps scan и thresholding.
- [backend/app/services/moderation/dedup_scoring.py](/home/andrey-debian/Projects/wardrobe-parser-platform/backend/app/services/moderation/dedup_scoring.py:140) строки 140-190 используют weighted scoring по title/vendor/price/handle/image/variant.

Doc references:
- [docs/backend-design/01-project-setup.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/backend-design/01-project-setup.md:107) строки 107-112 сводят всю область к `DEDUP_*`.
- [docs/backend-design/06-categories-dedup-and-merchandising.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/backend-design/06-categories-dedup-and-merchandising.md:53) строки 53-75 описывают feature-area, но не tuning scoring pipeline.
- [docs/api/data-models/pricing-settings.md](/home/andrey-debian/Projects/wardrobe-parser-platform/docs/api/data-models/pricing-settings.md:26) строка 26 описывает `dedup_only_available_products` как active behavior switch, тогда как current dedup code игнорирует этот DB setting и всегда использует available-only candidates.

Оценка:
- Это не пропущенный domain section, но это реальный accuracy-gap для тех, кто хочет сохранить текущее поведение dedup ровно как есть.

Docs need changes:
- Yes.
- Как минимум нужно:
  - перечислить активные runtime knobs dedup;
  - зафиксировать, что current candidate generation фактически остается available-only независимо от exposed flag `dedup_only_available_products`.

## 3. Остаточные области с низкой уверенностью

Эти области не выглядят явно пропущенными в утвержденном documentation set, но заслуживают второго прохода при cleanup docs:

- глубокое branch-поведение внутри `products.py` вокруг legacy proxy routes и probe helpers
- operational helper script `backend/scripts/reset_category_tree.py`
- устаревшее упоминание alias `/api/docs/showcase.md` в `backend/README.md`, которое находится вне аудируемых каталогов docs, но может путать инженеров
- dormant helper module `backend/app/services/media/image_security.py`, который присутствует в коде, но не был найден в активных backend request paths

## 4. Bottom line

Backend уже задокументирован достаточно хорошо, чтобы поддержать структурированное планирование рефакторинга. Оставшаяся работа — в основном работа на точность:

- исправить немногочисленные места, где docs описывают более красивый задуманный контракт вместо реального;
- показать текущую частичность settings transfer и sync state mapping;
- задокументировать designers branch и реальное behavior dedup/media storage.

После этих корректировок покрытие backend должно стать близким к полному для code-guided cleanup.
