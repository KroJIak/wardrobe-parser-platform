#!/usr/bin/env bash
# Watchdog витрины.
#
# Восстанавливает витрину в два шага: сначала перезапускает зависший
# контейнер бэкенда, и только если это не помогло — перезагружает хост.
# Так сайт возвращается за секунды вместо минуты, а хост остаётся
# последним рубежом для случая, когда зависло всё.
#
# Проверка идёт по адресу контейнера: порты бэкенда наружу не публикуются,
# поэтому localhost:8000 на хосте не отвечает.
set -u

STATE_DIR="/var/lib/site-watchdog"
STATE_FILE="${STATE_DIR}/failures"
RESTART_MARKER="${STATE_DIR}/restarted"
LOG_FILE="/var/log/site-watchdog.log"
BACKEND_CONTAINER="wardrobe-y0oyt1-backend-1"
BACKEND_PORT=8000
FAILURES_TO_RESTART=3
FAILURES_TO_REBOOT=10

log() {
  printf '%s %s\n' "$(date -Is)" "$*" >>"${LOG_FILE}"
}

mkdir -p "${STATE_DIR}"

failures=0
if [ -f "${STATE_FILE}" ]; then
  failures="$(cat "${STATE_FILE}" 2>/dev/null || echo 0)"
  case "${failures}" in
    ''|*[!0-9]*) failures=0 ;;
  esac
fi

container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "${BACKEND_CONTAINER}" 2>/dev/null || echo false)" = "true" ]
}

backend_answers() {
  local ip
  container_running || return 1
  ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${BACKEND_CONTAINER}" 2>/dev/null || true)"
  [ -n "${ip}" ] || return 1
  curl -fsS --max-time 8 -o /dev/null "http://${ip}:${BACKEND_PORT}/health"
}

if backend_answers; then
  if [ "${failures}" -gt 0 ]; then
    log "бэкенд снова отвечает после ${failures} неудачных проверок"
  fi
  echo 0 >"${STATE_FILE}"
  rm -f "${RESTART_MARKER}"
  exit 0
fi

failures=$((failures + 1))
echo "${failures}" >"${STATE_FILE}"
log "бэкенд не отвечает (проверка ${failures})"

# Первый шаг: перезапустить контейнер. Если он и так перезапуляется
# по restart policy, ждём — Docker поднимет его сам.
if [ "${failures}" -eq "${FAILURES_TO_RESTART}" ] && [ ! -f "${RESTART_MARKER}" ]; then
  touch "${RESTART_MARKER}"
  if container_running; then
    log "контейнер запущен, но не отвечает — перезапускаю его"
    timeout 120 docker restart "${BACKEND_CONTAINER}" >/dev/null 2>&1 || true
  else
    log "контейнер не запущен — жду авто-перезапуск Docker"
  fi
  exit 0
fi

if [ "${failures}" -lt "${FAILURES_TO_REBOOT}" ]; then
  exit 0
fi

# Сборка или деплой временно гасят контейнеры и грузят процессор —
# перезагрузка в этот момент только сорвёт работу.
if pgrep -f "docker build|buildkit|buildx|npm ci|npm run build|vite build" >/dev/null 2>&1; then
  log "перезагрузка отложена: идёт сборка или деплой"
  echo 0 >"${STATE_FILE}"
  exit 0
fi

log "бэкенд не отвечает ${failures} проверок подряд и перезапуск не помог — перезагружаю хост"
echo 0 >"${STATE_FILE}"
systemctl reboot
