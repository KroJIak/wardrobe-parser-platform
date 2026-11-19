# Файлы эксплуатации витрины

Здесь лежат настройки устойчивости сервера, которые устанавливаются на хост
вручную: сам Docker и Compose их не разворачивают.

| Файл | Куда на хосте | Что делает |
|------|----------------|------------|
| `site-watchdog.sh` | `/usr/local/bin/site-watchdog.sh` | проверяет бэкенд, перезапускает контейнер, затем перезагружает хост |
| `systemd/site-watchdog.service` | `/etc/systemd/system/` | запуск проверки |
| `systemd/site-watchdog.timer` | `/etc/systemd/system/` | таймер: проверка раз в минуту |
| `systemd/docker-prune.service` | `/etc/systemd/system/` | очистка неиспользуемых образов, сборок и томов |
| `systemd/docker-prune.timer` | `/etc/systemd/system/` | таймер: очистка раз в сутки |
| `systemd/10-docker-limits.conf` | `/etc/systemd/system/docker.service.d/` | лимиты памяти самого Docker и запрет свопа |

## Установка

```bash
install -m 0755 site-watchdog.sh /usr/local/bin/site-watchdog.sh
install -m 0644 systemd/site-watchdog.service /etc/systemd/system/site-watchdog.service
install -m 0644 systemd/site-watchdog.timer /etc/systemd/system/site-watchdog.timer
install -m 0644 systemd/docker-prune.service /etc/systemd/system/docker-prune.service
install -m 0644 systemd/docker-prune.timer /etc/systemd/system/docker-prune.timer
mkdir -p /etc/systemd/system/docker.service.d
install -m 0644 systemd/10-docker-limits.conf /etc/systemd/system/docker.service.d/10-docker-limits.conf

systemctl daemon-reload
systemctl enable --now site-watchdog.timer docker-prune.timer
systemctl restart docker   # применяет лимиты демона, контейнеры перезапустятся
```

## Проверка

```bash
systemctl list-timers | grep -E "site-watchdog|docker-prune"
/usr/local/bin/site-watchdog.sh; echo $?   # 0 — витрина отвечает
cat /var/lib/site-watchdog/failures        # счётчик неудачных проверок
tail -f /var/log/site-watchdog.log
```

Подробности и обоснование: `docs/infra-design/04-server-resilience.md`.
