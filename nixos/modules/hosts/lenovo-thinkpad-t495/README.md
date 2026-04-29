# ThinkPad T495: Matrix + mautrix-telegram (шпаргалка)

Цель: поднять Matrix на домене `matrix.nixos.netcraze.pro` (федерация работает), плюс мост Telegram.

Конфиг: `nixos/modules/hosts/lenovo-thinkpad-t495/configuration.nix`

## 0) Внешний доступ (важно)

Трафик к `matrix.nixos.netcraze.pro` должен попадать на сервисы этого хоста.

Важно: на внешнем уровне (reverse proxy / ingress) нельзя включать авторизацию для путей:
- `/_matrix`
- `/_synapse`

Иначе ломаются клиенты и федерация.

## 1) Собрать и применить

На хосте:

```
sudo nixos-rebuild switch --flake ~/dotfiles/nixos#thinkpad-t495
```

## 2) Заполнить секреты Telegram (обязательно)

1) Создать приложение в Telegram: https://my.telegram.org/apps
2) Заполнить файл:

- `/var/lib/mautrix-telegram/secrets.env`

Содержимое (пример):

```
MAUTRIX_TELEGRAM_TELEGRAM_API_ID=123456
MAUTRIX_TELEGRAM_TELEGRAM_API_HASH=0123456789abcdef0123456789abcdef
```

Перезапусти мост:

```
sudo systemctl restart mautrix-telegram.service
```

## 3) Настроить Basic Auth (рекомендуется)

nginx на хосте:
- публично отдаёт только `/_matrix` и `/_synapse`
- закрывает Basic Auth:
  - `/_synapse/admin`
  - `/` (и возвращает 404, чтобы не светить лишнее)

Создать пользователя для Basic Auth:

```
sudo htpasswd -c /var/lib/nginx/matrix.htpasswd admin
sudo systemctl reload nginx.service
```

## 4) Создать Matrix-пользователя и выдать админку (Synapse)

В конфиге регистрации выключены (`enable_registration = false`), поэтому юзера создаём вручную.

1) Посмотреть секрет для регистраций:

```
sudo cat /var/lib/matrix-synapse/homeserver.yaml | rg \"registration_shared_secret\"
```

2) Создать админа (пример для пользователя `nixos`):

```
sudo -u matrix-synapse register_new_matrix_user \\
  -c /var/lib/matrix-synapse/homeserver.yaml \\
  -a \\
  -u nixos \\
  -p '<PASSWORD>' \\
  http://127.0.0.1:8008
```

## 5) Проверки “живое?”

Снаружи (из браузера):
- `https://matrix.nixos.netcraze.pro/_matrix/client/versions`

На хосте:

```
systemctl status matrix-synapse.service
systemctl status mautrix-telegram.service
systemctl status nginx.service

journalctl -u matrix-synapse -b --no-pager | tail -n 50
journalctl -u mautrix-telegram -b --no-pager | tail -n 100
```

## Порты (таблица)

| Где | Порт | Кто слушает | Для чего |
|-----|------|-------------|----------|
| Хост (внешний) | 80/tcp | nginx | HTTP reverse-proxy (Matrix endpoints) |
| Хост (локально) | 8008/tcp | synapse | Matrix Client-Server + Federation (за nginx) |
| Хост (локально) | 29317/tcp | mautrix-telegram | appservice HTTP (синхронизация моста с Synapse) |
| Хост (локально) | 5432 (unix socket) | postgresql | Базы Synapse и моста (`/run/postgresql`) |
