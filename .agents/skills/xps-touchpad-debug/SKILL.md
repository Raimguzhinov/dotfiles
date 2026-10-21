---
name: xps-touchpad-debug
description: Диагностика тачпада/курсора на Dell XPS 13 Plus 9320 (Elan 04F3:31D1) — курсор уезжает сам, «лишний палец» после сна, залипший клик/выделение, тачпад мёртв после resume. Использовать при любой жалобе на тачпад, курсор или клики на этом ноутбуке.
---

# Диагностика тачпада XPS 9320

Сначала прочитать раздел «Тачпад» в `AGENTS.md` — там таблица уже известных
причин и фиксов. Цель — за 2–3 команды определить слой: **прошивка/I2C →
ядро → libinput в niri**. Не гадать и не чинить до этого.

## 1. Без root (сразу)

```bash
journalctl -k -b --no-pager | grep -cE 'i2c_designware.1: (spurious STOP|controller timed out)'
journalctl -k -b --no-pager | grep -E 'i2c_designware.1|VEN_04F3|i2c_hid' | tail -5
journalctl --user -b --no-pager | grep -E 'libinput (error|bug)' | tail -10
journalctl -b --no-pager | grep -E 'will (suspend|hibernate|hybrid sleep)|PM: .*(entry|exit)|Operation .* finished' | tail -10
systemctl status xps-touchpad-reset-post-resume --no-pager | head -5
grep -E '^ *12:' /proc/interrupts
lsmod | grep -E 'psmouse|hid_multitouch|i2c_hid'
readlink /sys/bus/i2c/devices/i2c-VEN_04F3:00/driver
```

- Флуд `spurious STOP` → I2C/прошивка. Лечится rebind (п. 3).
- Какой сон был: `hybrid sleep`/долгий s2idle на пустой батарее — исторический триггер.
- libinput логирует максимум 5 сообщений на устройство за 24 ч — отсутствие
  ошибок в журнале ничего не доказывает.
- Рост IRQ 12 при кликах тачпадом → события идут ещё и через PS/2 (psmouse
  должен быть в блеклисте).

## 2. Ядро vs libinput (нужен root — отпечаток пальца, пользователь должен быть у ноутбука)

Номера `eventN` меняются после rebind — искать по имени:

```bash
for d in /sys/class/input/event*; do echo "${d##*/} $(cat $d/device/name)"; done | grep -E '04F3:31D1|PS/2'
sudo python3 ~/dotfiles/.claude/skills/xps-touchpad-debug/tpstate.py /dev/input/eventN 20
sudo $(nix build --no-link --print-out-paths nixpkgs#libinput.bin)/bin/libinput debug-events --device /dev/input/eventN
```

`tpstate.py` печатает снимок MT-слотов (tracking id, tool FINGER/PALM) и
нажатых клавиш из ядра, затем поток DOWN/UP/tool/BTN_LEFT/SYN_DROPPED.

| Ядро | свежий `libinput debug-events` | niri | Вывод |
|---|---|---|---|
| норм | норм | сбой | stale state libinput в niri (как #1319) — искать upstream-фикс libinput, временно патч в `overlays.nix` |
| `tool=PALM` на одном пальце / нет `BTN_LEFT` | сбой | сбой | прошивка Elan → rebind |
| `id≠-1` без пальцев, `BTN_LEFT=1` без нажатия | сбой | сбой | фантом в прошивке/ядре → rebind |
| `BTN_LEFT=1` на `PS/2 Generic Mouse` | — | — | psmouse |
| `SYN_DROPPED` | — | — | потеря событий (niri лагает) |

## 3. Немедленное восстановление

Rebind (`xps-touchpad-reset-post-resume`, unbind/bind) **не делать**: повторный
probe сам вешает шину (октябрь 2026, 2 из 3 в покое). При зависании шины
(`controller timed out` / `timeout waiting for bus ready`) поможет только
обесточивание Elan: пользователь сам делает `systemctl hibernate` и будит
ноутбук кнопкой (сам ноутбук из S4 не выходит, гибернацию не запускать).
Обычно это делает `xps-touchpad-watchdog` после активной проверки через `hidraw`.
НИКОГДА не делать `modprobe -r i2c_designware_*`/`i2c_hid_acpi`.

Перед восстановлением снять улики: `sudo cat /sys/kernel/debug/pinctrl/INTC1055:00/pins`
(рабочие I2C-пады 79–82, бит 1 PADCFG0 = уровень линии; в октябре 2026 оба
были высокие, то есть линии никто не держал).

Стресс-стенд (при зависании останавливается с кодом 3):
`sudo systemd-run --unit=tp-stress --collect -p KillMode=mixed -E PATH=/run/current-system/sw/bin:/run/wrappers/bin -E PYTHON=/run/current-system/sw/bin/python3 /run/current-system/sw/bin/bash ~/dotfiles/.claude/skills/xps-touchpad-debug/stress/run.sh OUT [default|t2a|ec]`

## 4. Поиск upstream

SearXNG для общего веба почти бесполезен. Работает:
- libinput issues: `curl -s "https://gitlab.freedesktop.org/api/v4/projects/libinput%2Flibinput/issues?search=<q>&scope=all&per_page=30"`
- коммиты libinput после текущей версии: `.../repository/compare?from=<ver>&to=main`
- исходники ядра: `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/<path>?h=linux-7.2.y`
- nixos-hardware: `git clone --depth 1` (без `--filter=blob:none` — иначе зависает на ленивых блобах)
- `mcp__grep__searchGitHub` для реальных примеров (`/sys/bus/i2c/drivers/i2c_hid_acpi/unbind`)
