# Dell XPS 13 Plus 9320 (dell-xps-13-9320)

Ключевые особенности/хелперы живут в
`nixos/modules/hosts/dell-xps-13-9320/hardware.nix`.

- **Ядро**: используется `boot.kernelPackages = pkgs.linuxPackages_latest;`
  (актуальное ядро из nixpkgs).
- **int3472 GPIO patch**: не применяется (фикс в современных ядрах уже
  upstream). Это уменьшает вероятность локальной пересборки ядра при
  `flake update`.

## Камера (IPU6EP)

- Используется `hardware.ipu6.enable = true` + `libcamera`.
- Дефолтный `v4l2-relayd` ipu6 instance отключён:
  `services.v4l2-relayd.instances.ipu6.enable = lib.mkForce false`.
- Для legacy приложений используется `v4l2loopback` и ручной `camera-bridge`.

**Важно:** утверждение «камера после S4 не восстанавливается» — это
наблюдение/гипотеза, а не 100% факт. Для перепроверки добавлен best-effort
сервис `xps-camera-recover` (post-resume).

## Микрофон (SoundWire rt714)

- `xps-mic-fix.service` применяет ALSA routing на буте.
- В `xps-mic-fix` есть workaround для
  `/var/lib/alsa/card0.conf.d/ctl-remap.conf`: если там оказался битый симлинк в
  GC’d `/nix/store`, он удаляется и создаётся пустой файл.

## Swap и гибернация

- Swap: `/swap/swapfile` (32G) в btrfs-сабволюме `swap` внутри LUKS
  (`cryptroot`). `boot.resumeDevice = "/dev/mapper/cryptroot"` и
  `resume_offset` в `boot.kernelParams`.
- `resume_offset` берётся из
  `btrfs inspect-internal map-swapfile -r /swap/swapfile`. При пересоздании
  файла его нужно обновить, иначе resume не найдёт образ.
- Сабволюм `swap` не снапшотить: btrfs не даст, пока swapfile активен.
- Новые `resume=`/`resume_offset` начинают работать только после
  перезагрузки. До неё logind отвечает `CanHibernate=na`, и
  `suspend-then-hibernate` молча становится обычным suspend.

## Отпечаток и PAM

- Опция `pam_fprintd` пишется `max-tries=` (через дефис). `max_tries`
  молча игнорируется. sudo: `debug max-tries=5 timeout=30`.
- Сканер Goodix `27c6:63bc` быстро тратит попытки (fprintd #217), поэтому
  нужен запас по `max-tries` и `timeout`.
- ly 1.4.1 не умеет входить только по отпечатку (codeberg ly #227), поэтому
  `pam_fprintd` из стека ly убран.

## Post-resume хелперы

- `xps-auth-post-resume` (рестарт `fprintd` и `polkit-soteria`) удалён
  (октябрь 2026): сбои отпечатка в sudo шли от настроек `pam_fprintd`, см.
  «Отпечаток и PAM».
- `xps-touchpad-reset-post-resume` (unbind/bind `i2c-VEN_04F3:00`) из
  resume-хука **убран** (октябрь 2026): именно этот повторный probe вешал
  шину тачпада. Юнит оставлен только для ручного вызова, и тоже рискованно.
- Все post-resume сервисы запускаются из `powerManagement.resumeCommands`
  (скрипт `ExecStop` у `sleep-actions.service`), а не через
  `post-resume.target` — такого таргета нет.

## Тачпад (Elan `VEN_04F3:00 04F3:31D1`, haptic)

Цепочка: `i2c_designware.1` (встроен в ядро, `=y`) → `i2c-VEN_04F3:00` →
`i2c_hid_acpi` → `hid-multitouch` (класс `MT_CLS_WIN_8`). Узлы: `… Mouse`,
`… Touchpad`, `… UNKNOWN`. Давление не отдаёт, клик генерирует прошивка.

Известные проблемы и фиксы (сентябрь 2026):

| Симптом | Причина | Фикс |
|---|---|---|
| После resume курсор сам уезжает, в `dmesg` флуд `i2c_designware.1: spurious STOP detected` | не воспроизводится с октября 2026 (0 из 230 циклов s2idle). Гипотеза: эмуляция тачпада в EC Dell (второй мастер на шине) | раньше лечилось rebind, теперь rebind запрещён (см. ниже) |
| Тачпад мёртв, флуд `controller timed out` / `timeout waiting for bus ready` / `-110` | повторный probe `i2c_hid` (unbind/bind) вешает шину: первое чтение feature report 2 после reset не завершается. 4/54 rebind после resume, 2/3 rebind в покое, 2/6 загрузок, когда probe шёл через ~60 с после ядра (EC держал шину до `_DSM`). SDA/SCL при этом высокие, rebind и сброс контроллера не помогают | rebind не делать; probe в initrd (`boot.initrd.kernelModules`: `pinctrl_tigerlake intel_lpss_pci idma64 i2c_hid_acpi hid_multitouch`); восстановление только гибернацией через `xps-touchpad-watchdog` |
| После сна «нужен лишний палец» (1 палец — ничего, 2 — курсор), само проходит | libinput #1319: протухший `is_tool_palm` у слота после закрытия fd (крышка → `tp_suspend(SUSPEND_LID)`) | патч libinput в overlay (см. ниже) |
| Раз в день «зажата кнопка» (движение = выделение/drag) | не доказано; главная гипотеза — второй путь тачпада через PS/2 (`DLL0af3` на i8042 AUX) | `boot.blacklistedKernelModules = [ "psmouse" ]` |

- `HibernateDelaySec` и `HibernateMode=shutdown` задаются в
  `systemd.sleep.settings.Sleep`, а не в logind: logind этот ключ
  игнорирует. До октября 2026 из-за этого `suspend-then-hibernate` никогда
  не гибернировал, и ноутбук с закрытой крышкой спал в s2idle до разряда
  батареи («лимбо»). `shutdown` обходит S4-путь прошивки Dell.
- `services.upower.criticalPowerAction = "Hibernate"`: дефолтный
  `HybridSleep` при 2% оставлял машину в s2idle на пустой батарее
  (один из триггеров сбоя тачпада, плюс hybrid-sleep 25.09 потерял сессию).
- **Не использовать** `modprobe -r i2c_designware_*` (скрипт nixos-hardware
  `sleep-resume/i2c-designware`): модуль встроен, `modprobe -r` для него
  no-op, а `i2c_hid_acpi` после этого никто не загружает — тачпад мёртв до
  ребута. Именно это «ломало тачпад» в старой попытке.
- `tap = false`, `dwt = false` в niri — tap-and-drag/drag-lock к залипанию
  кнопки отношения не имеют.
- `xps-touchpad-watchdog`: по строке `i2c-VEN_04F3:00: failed to` в
  журнале ядра делает активную проверку (`HIDIOCGFEATURE` report 2 через
  `hidraw`) и, только если тачпад не отвечает, уходит в `systemctl hibernate`
  (не чаще раза в 10 минут). Ошибки, записанные при входе в гибернацию,
  после resume приходят в журнал со свежим временем. Поэтому смотреть только
  в журнал нельзя: это двойная гибернация.
- Проверено и **не работает**: пауза после HID RESET в `i2c-hid`
  (out-of-tree патч, 300 мс), сброс контроллера I2C1, 9 тактов SCL
  (линии не прижаты). В ACPI у тачпада нет ни питания, ни reset-пина.
- Стенд стресс-тестов: `.claude/skills/xps-touchpad-debug/stress/`
  (`run.sh OUT [default|t2a|ec]`). Он никогда не гибернирует, при
  зависании останавливается с кодом 3.

Диагностика в момент сбоя — навык `.claude/skills/xps-touchpad-debug`
(локальный, `.claude` в gitignore). Ключевое: сравнить состояние ядра
(`EVIOCGMTSLOTS`/`EVIOCGKEY` на `/dev/input/eventN`) со свежим
`libinput debug-events` и с поведением niri — это сразу делит баг на
прошивка/ядро/libinput композитора.

## Временные upstream-патчи (удалить, когда придут из nixpkgs)

- **libinput `d0e6d43a` («touchpad: sync the slot's tool type when syncing
  touch state», issue #1319, MR !1505)** — в `nixos/modules/overlays.nix`
  подмешивается только в `niri-unstable` (единственный niri в системе,
  без массовой пересборки). Фикс есть в libinput ≥ 1.31.901 / 1.32.0.
  При `nixos-rebuild` overlay сам выдаёт `warning: overlays.nix: libinput …
  already contains d0e6d43a`, как только в nixpkgs libinput ≥ 1.31.901.
  Ручная проверка:
  `nix eval --raw ~/dotfiles/nixos#nixosConfigurations.raimguzhinov.pkgs.libinput.version`.
  Увидел warning — удалить `let libinput = …` и оверрайд `niri-unstable`
  из overlay (оставить только `doCheck = false` у `niri`).
  Если `fetchpatch` перестанет применяться (патч уже внутри) — это тот же
  сигнал.
- niri: единственный пакет — `niri-unstable`, задаётся в NixOS
  `programs.niri.package` (`configuration.nix`). NixOS-модуль niri-flake
  через `mkForce` навязывает свой пакет в HM, поэтому `package` в HM
  (`niri.nix`) не задавать — он игнорируется. Дефолт модуля — `niri-stable`,
  без явного `programs.niri.package` незаметно откатится на него.
