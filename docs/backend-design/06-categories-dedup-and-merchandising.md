# Архитектура Backend: Категории, Dedup и Merchandising

## Область
- Покрывает: управление деревом категорий, public API для меню категорий, manual category links, потоки dedup-модерации, brand mapping и product curation, ориентированную на merchandising.
- Не покрывает: механику выполнения sync или internals pricing formula.
- Зависит от: `03-data-layer-and-schema-ownership.md`, `05-product-catalog-and-public-showcase.md`.

## Домен категорий
Функциональность categories разделена между:

- router: `app/api/v1/categories.py`
- services: `CategoryTreeService`, `CategoryIndexService`
- tables/models для tree, keywords, manual links, index snapshots и state

### Группы endpoints для categories
| Группа endpoints | Назначение | Auth |
|---|---|---|
| `GET /categories/tree` | admin view tree | `control.categories.read` |
| `GET /catalog/categories/roots` | public menu root categories | public |
| `GET /catalog/categories/root/{root_slug}` | public enabled subtree | public |
| `POST/PATCH/DELETE /categories...` | CRUD categories | `control.categories.edit` |
| `POST/DELETE /categories/{id}/keywords...` | CRUD keyword rules | `control.categories.edit` |
| `GET /categories/{id}/manual-products...` | inspect/search manual links | `control.categories.read` |
| `POST/DELETE /categories/{id}/manual-products...` | поддержка manual links | `control.categories.edit` |

### Публичная проекция categories
Публичные responses categories - это не raw rows DB. Backend:

- читает полное enabled tree из `CategoryTreeService`;
- фильтрует enabled roots/subtrees;
- отображает internal nodes tree в облегченный `CatalogCategoryNodeResponse`;
- опционально включает precomputed counts products.

### Ручные связи категорий
Manual links важны для merchandising, потому что они:

- позволяют admin принудительно помещать products в categories;
- участвуют в назначениях favorite/starred category для showcase;
- повторно синхронизируются в state category index после некоторых операций product.

## Индекс категорий
`CategoryIndexService` - это precomputed read-side для projection `product -> category`.

Наблюдаемые обязанности:

- обеспечивать freshness index перед reads;
- rebuild full index после sync;
- возвращать сгруппированные ids categories по product;
- синхронизировать manual links для product после изменений starred-category.

Этот service - одна из главных причин, почему endpoints catalog могут проецировать internal categories без пересчета matches tree на каждом response.

## Ветка designers как системная поверхность categories
Category tree не является полностью manual. `CategoryTreeService` также поддерживает protected branch designers с root `Дизайнеры`.

Текущее поведение:
- регенерация branch определяется состоянием brand mapping, `designers_min_products` и проверками cadence sync
- `designers_exclude_store_vendors` влияет на то, какие vendors подходят для derived nodes designer
- ветка designers может неявно обновляться во время reads tree
- system branches, такие как fallback/designers, имеют более строгие правила mutation, чем обычные categories

Следствия protected-branch в текущем code:
- edits keywords могут блокироваться для protected system branches
- создание children может блокироваться для protected system branches
- семантика CRUD category, следовательно, отличается между обычными nodes и generated/system nodes

## Домен dedup
Функциональность dedup публикуется из `app/api/v1/dedup.py` через `DedupService`.

Endpoints:

- `GET /dedup/candidates`
- `POST /dedup/merge`
- `POST /dedup/reject`
- `POST /dedup/combine`
- `GET /dedup/decisions`
- `POST /dedup/undo`

Разрешения:

- reads требуют `control.dedup.read`
- mutations требуют `control.dedup.edit`

### Функциональная роль
Dedup - это не только review на admin-экране. Он также влияет на семантику catalog:

- merged/unavailable items влияют на то, что остается visible в responses catalog;
- sync apply logic проверяет состояние dedup, когда решает, какие missing source products нужно пометить unavailable;
- history decisions сохраняется в `ParserDedupDecision`.

### Факты runtime scoring и gating
Текущее поведение dedup формируется одновременно DB-backed settings и runtime knobs backend:
- значения config `DEDUP_*` управляют thresholding score, caps pair/bucket и weighting
- scoring комбинирует сигналы title, vendor, price, handle, image и variant
- генерация candidates в текущем runtime code фактически ограничена available products

Важный текущий caveat:
- поле `dedup_only_available_products` присутствует в public/admin payload settings
- текущая генерация candidates dedup фактически не переключает поведение по этому полю и все равно ведет себя как available-only

## Сопоставление брендов как слой merchandising
Brand/designer mapping реализован через `BrandMappingService`, но публикуется внутри router products.

Практическая роль:

- нормализовать vendor names между heterogeneous sources;
- позволять curation displayed brand labels на стороне admin;
- участвовать и в public, и в admin projections products.

Это concern merchandising/read-model, а не чистая concern source ingestion.

## Как эти зоны взаимодействуют
Текущий поток данных:

```text
Sync/imported product
  -> dedup state may hide/merge it
  -> category index assigns category ids
  -> manual links can override/add placements
  -> brand mapping adjusts vendor label
  -> showcase/starred category curation promotes selected category relations
  -> public/admin product projections read all of the above
```

Следовательно, backend владеет большей частью семантики curation после raw parsing.

## Заметки о текущем состоянии
- Операции чтения и записи categories относительно чисто разделены на уровне router, но projection logic повторно используется также из flows product/catalog.
- Назначение favorite/starred category product реализовано в `products.py`, а не в `categories.py`.
- Endpoints brand mapping живут в `products.py`, поэтому concerns merchandising распределены по нескольким routers.
- Следствия dedup видны за пределами `dedup.py`; они участвуют в логике availability product и reconciliation sync.
