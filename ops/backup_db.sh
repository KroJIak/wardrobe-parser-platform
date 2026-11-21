#!/usr/bin/env bash
# Бэкап БД витрины: логическая копия (pg_dump) и физическая копия тома
# (pg_basebackup). Согласованная физическая копия снимается без остановки
# сервиса, поэтому сайт продолжает работать.
set -u

BACKUP_DIR="/var/backups/wardrobe"
STAMP="$(date +%Y%m%d-%H%M%S)"
PG_CONTAINER="wardrobe-y0oyt1-postgres-1"
PG_USER="wardrobe"
PG_DB="wardrobe_db"
LOG="${BACKUP_DIR}/backup-${STAMP}.log"

mkdir -p "${BACKUP_DIR}"
exec >>"${LOG}" 2>&1

echo "=== бэкап начат ${STAMP} ==="
df -h / | tail -1

# 1. Логическая копия: восстанавливается через pg_restore, не зависит от версии
#    сервера и не требует остановки базы.
echo "--- pg_dump ---"
docker exec "${PG_CONTAINER}" pg_dump -U "${PG_USER}" -d "${PG_DB}" -Fc --no-owner --no-privileges \
  > "${BACKUP_DIR}/wardrobe_db-${STAMP}.dump"
echo "pg_dump: код=$? размер=$(du -h "${BACKUP_DIR}/wardrobe_db-${STAMP}.dump" | cut -f1)"

# 2. Физическая копия тома: снимается штатным pg_basebackup, поэтому
#    согласованна и не требует останавливать базу.
echo "--- pg_basebackup ---"
docker exec "${PG_CONTAINER}" bash -c '
  rm -rf /tmp/pgbase && mkdir -p /tmp/pgbase &&
  pg_basebackup -U '"${PG_USER}"' -D /tmp/pgbase -Ft -X stream -c fast --no-password &&
  tar -C /tmp/pgbase -czf /tmp/pgbase.tar.gz .
'
docker cp "${PG_CONTAINER}:/tmp/pgbase.tar.gz" "${BACKUP_DIR}/postgres_volume-${STAMP}.tar.gz"
docker exec "${PG_CONTAINER}" rm -rf /tmp/pgbase /tmp/pgbase.tar.gz
echo "volume: размер=$(du -h "${BACKUP_DIR}/postgres_volume-${STAMP}.tar.gz" | cut -f1)"

# 3. Контрольные суммы и отметка о завершении.
cd "${BACKUP_DIR}"
sha256sum "wardrobe_db-${STAMP}.dump" "postgres_volume-${STAMP}.tar.gz" > "checksums-${STAMP}.sha256"
touch "backup-${STAMP}.done"

# 4. Retention: копии старше двух недель больше не нужны.
find "${BACKUP_DIR}" -maxdepth 1 -type f -name "wardrobe_db-*.dump" -mtime +14 -delete
find "${BACKUP_DIR}" -maxdepth 1 -type f -name "postgres_volume-*.tar.gz" -mtime +14 -delete
find "${BACKUP_DIR}" -maxdepth 1 -type f -name "checksums-*.sha256" -mtime +14 -delete
find "${BACKUP_DIR}" -maxdepth 1 -type f -name "backup-*.log" -mtime +14 -delete

echo "=== бэкап завершён ==="
ls -la "${BACKUP_DIR}" | tail -6
df -h / | tail -1
