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
| `ssh/98-wardrobe-resilience.conf` | `/etc/ssh/sshd_config.d/` | запас под сканирование порта 22 |
| `fail2ban/dokploy-sshd.local` | `/etc/fail2ban/jail.d/` | jail sshd: полчаса бана, пять попыток, админ-IP вне бана |
| `fail2ban/sshd-wardrobe.local` | `/etc/fail2ban/filter.d/` | бан только за перебор логинов, обрыв соединения не считается |
| `backup_db.sh` | `/usr/local/bin/backup_db.sh` | бэкап БД: логическая копия и копия тома |
| `systemd/backup-db.service` | `/etc/systemd/system/` | запуск бэкапа |
| `systemd/backup-db.timer` | `/etc/systemd/system/` | таймер: бэкап раз в сутки |

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

Настройки доступа по SSH и бана переборщиков ставятся отдельно: на хосте
уже есть drop-in от Dokploy, поэтому свой файл добавляется рядом и
перезагружает только sshd, не обрывая активные сессии.

```bash
install -m 0644 ssh/98-wardrobe-resilience.conf /etc/ssh/sshd_config.d/98-wardrobe-resilience.conf
sshd -t && systemctl reload ssh

install -m 0644 fail2ban/sshd-wardrobe.local /etc/fail2ban/filter.d/sshd-wardrobe.local
install -m 0644 fail2ban/dokploy-sshd.local /etc/fail2ban/jail.d/dokploy-sshd.local
fail2ban-client reload
```

Бэкап базы ставится отдельно: скрипт снимает копию сам, а таймер запускает
её раз в сутки и хранит две недели истории.

```bash
install -m 0755 backup_db.sh /usr/local/bin/backup_db.sh
install -m 0644 systemd/backup-db.service /etc/systemd/system/backup-db.service
install -m 0644 systemd/backup-db.timer /etc/systemd/system/backup-db.timer
systemctl daemon-reload
systemctl enable --now backup-db.timer
```

Копии складываются в `/var/backups/wardrobe`: логическая (`pg_dump`) и
физическая (`pg_basebackup`) — обе согласованные и снимаются без остановки
витрины.

## Проверка

```bash
systemctl list-timers | grep -E "site-watchdog|docker-prune"
/usr/local/bin/site-watchdog.sh; echo $?   # 0 — витрина отвечает
cat /var/lib/site-watchdog/failures        # счётчик неудачных проверок
tail -f /var/log/site-watchdog.log
```

Подробности и обоснование: `docs/infra-design/04-server-resilience.md`.
