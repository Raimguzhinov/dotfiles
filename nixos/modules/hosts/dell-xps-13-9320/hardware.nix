{ ... }:
{
  # Hardware configuration for Dell XPS 13 Plus 9320
  flake.nixosModules.hwDellXps9320 =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];

      # Kernel pinning: keeps updates predictable and avoids surprise jumps.
      # Also helps Nix reuse binary caches (important for faster `nix flake update` cycles).
      boot.kernelPackages = pkgs.linuxPackages_6_19;

      fileSystems."/" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        options = [ "subvol=root" ];
      };

      boot.initrd.luks.devices."cryptroot".device =
        "/dev/disk/by-uuid/ebb84402-b2b3-41fa-bdfa-ca83bc69c1e4";

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/F92F-3A2C";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      fileSystems."/home" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        options = [ "subvol=home" ];
      };

      fileSystems."/nix" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        options = [ "subvol=nix" ];
      };

      swapDevices = [
        { device = "/dev/disk/by-uuid/67de0ed7-3439-4495-a77b-124b27ab717a"; }
      ];

      # Resume from hibernate: must match swap device UUID above
      boot.resumeDevice = "/dev/disk/by-uuid/67de0ed7-3439-4495-a77b-124b27ab717a";

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      hardware.enableAllFirmware = true;

      # IPU6EP webcam — modern approach: hardware.ipu6 + libcamera, no icamerasrc
      hardware.ipu6 = {
        enable = true;
        platform = "ipu6ep";
      };
      # Default v4l2-relayd ipu6 instance uses icamerasrc which doesn't work on 9320
      services.v4l2-relayd.instances.ipu6.enable = lib.mkForce false;
      hardware.firmware = [
        pkgs.ivsc-firmware
        pkgs.sof-firmware
      ];

      # NOTE: historically this machine needed an intel_int3472 patch (GPIO type 0x02).
      # On modern kernels (incl. 6.19.x) this logic is already upstream, so we intentionally
      # avoid kernel patching here to keep the kernel cacheable and updates fast.

      boot.kernelModules = [
        "kvm-intel"
        "dell-privacy"
        "v4l2loopback"
      ];
      boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
      # Legacy support: loopback device for apps that can't use PipeWire portal (OBS, ffplay, etc.)
      # Bridge is started manually: systemctl start camera-bridge
      boot.extraModprobeConfig = ''
        options v4l2loopback video_nr=40 card_label="libcamera Virtual" exclusive_caps=1
      '';

      # Finds the active ipu6 capture device and creates /dev/camera-active symlink
      systemd.services.camera-setup = {
        description = "Setup camera device symlink";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = 5;
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "camera-setup" ''
            ${pkgs.systemd}/bin/udevadm settle --timeout=10
            for attempt in $(seq 1 10); do
              ACTIVE_DEVICE=$(${pkgs.v4l-utils}/bin/media-ctl --print-topology 2>/dev/null | \
                ${pkgs.gnugrep}/bin/grep -B 3 "ENABLED" | \
                ${pkgs.gnugrep}/bin/grep "device node name" | \
                ${pkgs.gnugrep}/bin/grep -o "/dev/video[0-9]*" | head -1)
              if [ -n "$ACTIVE_DEVICE" ]; then
                ln -sf "$ACTIVE_DEVICE" /dev/camera-active
                echo "Camera active device: $ACTIVE_DEVICE -> /dev/camera-active"
                exit 0
              else
                echo "Attempt $attempt: No active camera found, waiting..."
                sleep 2
              fi
            done
            echo "ERROR: No active camera found after 10 attempts"
            exit 1
          '';
        };
      };

      # Bridge libcamera → v4l2loopback for legacy apps. Manual start/stop only.
      systemd.services.camera-bridge = {
        description = "libcamera → v4l2loopback bridge (legacy)";
        after = [
          "camera-setup.service"
          "systemd-modules-load.service"
        ];
        requires = [
          "camera-setup.service"
          "systemd-modules-load.service"
        ];
        path =
          with pkgs;
          (with gst_all_1; [
            gstreamer
            gst-plugins-base
            gst-plugins-good
            gst-plugins-bad
            gst-plugins-ugly
            gst-libav
            gst-vaapi
          ])
          ++ [ libcamera ];
        environment = {
          GST_PLUGIN_SYSTEM_PATH_1_0 = lib.concatStringsSep ":" [
            "${pkgs.gst_all_1.gstreamer.out}/lib/gstreamer-1.0"
            "${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
            "${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
            "${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0"
            "${pkgs.libcamera}/lib/gstreamer-1.0"
            "/run/current-system/sw/lib/gstreamer-1.0"
          ];
        };
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = 5;
          KillMode = "control-group";
          TimeoutStopSec = 5;
          ExecStartPre = pkgs.writeShellScript "camera-bridge-pre" ''
            attempt=0
            while [ $attempt -lt 30 ]; do
              if [ -L /dev/camera-active ] && [ -e /dev/camera-active ]; then
                echo "Found /dev/camera-active -> $(readlink /dev/camera-active)"
                break
              fi
              attempt=$((attempt + 1))
              echo "Waiting for /dev/camera-active... ($attempt/30)"
              sleep 1
            done
            [ -L /dev/camera-active ] || { echo "ERROR: /dev/camera-active not found"; exit 1; }
            attempt=0
            while [ $attempt -lt 30 ]; do
              [ -c /dev/video40 ] && { echo "Found /dev/video40"; break; }
              attempt=$((attempt + 1))
              echo "Waiting for /dev/video40... ($attempt/30)"
              sleep 1
            done
            [ -c /dev/video40 ] || { echo "ERROR: /dev/video40 not found"; exit 1; }
          '';
          ExecStart = pkgs.writeShellScript "camera-bridge" ''
            echo "Starting bridge -> /dev/video40"
            exec ${lib.getExe' pkgs.gst_all_1.gstreamer "gst-launch-1.0"} -v \
              libcamerasrc ! \
              videoconvert ! \
              video/x-raw,format=YUY2 ! \
              v4l2sink device=/dev/video40 sync=false
          '';
        };
      };

      # Post-resume: restart fprintd + polkit agent to reduce race conditions.
      # This is especially helpful after hibernate/suspend where devices or D-Bus
      # activations may behave inconsistently.
      systemd.services.xps-auth-post-resume = {
        description = "XPS 9320: restart auth agents after resume";
        wantedBy = [ "post-resume.target" ];
        after = [ "post-resume.service" ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = 30;
        };
        script = ''
          set -eu

          echo "[xps-auth-post-resume] restart fprintd"
          ${pkgs.systemd}/bin/systemctl restart fprintd.service 2>/dev/null || true

          echo "[xps-auth-post-resume] restart polkit-soteria for all users"
          ${pkgs.systemd}/bin/loginctl list-users --no-legend | ${pkgs.gawk}/bin/awk '{print $2}' | while read -r user; do
            ${pkgs.systemd}/bin/systemctl --user -M "$user@" restart polkit-soteria.service 2>/dev/null || true
          done
        '';
      };

      # Camera recover experiment (post-resume): tries to disprove/confirm the hypothesis
      # that the IPU6/IVSC camera stack cannot recover after S4. This is best-effort only.
      # Enable/disable by commenting out this service if it causes issues.
      systemd.services.xps-camera-recover = {
        description = "XPS 9320: best-effort camera recover after resume";
        wantedBy = [ "post-resume.target" ];
        after = [
          "post-resume.service"
          "systemd-modules-load.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = 60;
        };
        script = ''
          set -eu

          echo "[xps-camera-recover] starting"

          # Stop legacy bridge if running to free /dev/video40.
          ${pkgs.systemd}/bin/systemctl stop camera-bridge.service 2>/dev/null || true

          echo "[xps-camera-recover] devices before:"
          ${pkgs.coreutils}/bin/ls -la /dev/media* /dev/video* 2>/dev/null || true

          echo "[xps-camera-recover] trying to reload camera-related kernel modules (best-effort)"
          # Unload (order matters). Some modules may be busy; treat that as signal and continue.
          ${pkgs.kmod}/bin/modprobe -r intel_ipu6_psys 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe -r intel_ipu6_isys 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe -r intel_ipu6 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe -r ivsc_csi 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe -r ivsc_ace 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe -r mei_vsc 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe -r mei_vsc_hw 2>/dev/null || true

          ${pkgs.coreutils}/bin/sleep 1

          # Load back.
          ${pkgs.kmod}/bin/modprobe mei_vsc_hw 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe mei_vsc 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe ivsc_ace 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe ivsc_csi 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe intel_ipu6 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe intel_ipu6_isys 2>/dev/null || true
          ${pkgs.kmod}/bin/modprobe intel_ipu6_psys 2>/dev/null || true

          ${pkgs.coreutils}/bin/sleep 2

          # Recreate /dev/camera-active (if possible).
          ${pkgs.systemd}/bin/systemctl restart camera-setup.service 2>/dev/null || true

          echo "[xps-camera-recover] topology after (if available):"
          ${pkgs.v4l-utils}/bin/media-ctl --print-topology 2>/dev/null | ${pkgs.gnugrep}/bin/grep -E "ENABLED|entity|pad|link|device node name" || true

          echo "[xps-camera-recover] devices after:"
          ${pkgs.coreutils}/bin/ls -la /dev/media* /dev/video* 2>/dev/null || true

          echo "[xps-camera-recover] done"
        '';
      };

      # Восстановление звука и микрофона (SoundWire rt714) после S4-гибернации.
      # Rebind перезагружает DSP firmware SOF и заново перечисляет кодек rt714.
      # Камера (IVSC/ov01a10) после S4 часто не восстанавливается по наблюдениям.
      # Это гипотеза, а не 100% факт: см. xps-camera-recover для перепроверки.
      powerManagement.resumeCommands = ''
        echo "0000:00:1f.3" > /sys/bus/pci/drivers/sof-audio-pci-intel-tgl/unbind || true
        ${pkgs.coreutils}/bin/sleep 1
        echo "0000:00:1f.3" > /sys/bus/pci/drivers/sof-audio-pci-intel-tgl/bind || true
        # amixer -c 0 info готов раньше PCM-устройств SoundWire — ждём именно их,
        # иначе wireplumber стартует до появления hw:sofsoundwire,Np и не видит динамик.
        for i in $(${pkgs.coreutils}/bin/seq 1 120); do
          ${pkgs.alsa-utils}/bin/aplay -l 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "sofsoundwire" && break
          ${pkgs.coreutils}/bin/sleep 0.5
        done
        # Восстанавливаем маршрутизацию rt714 — сбрасывается при rebind.
        for dev in /sys/bus/soundwire/devices/*/power/control; do
          echo on > "$dev" || true
        done
        ${pkgs.alsa-utils}/bin/amixer -c 0 set 'rt714 ADC 22 Mux' 'DMIC1' || true
        ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='PGA5.0 5 Master Capture Switch' 'on,on' || true
        ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Switch' 'on' || true
        ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Volume' '70' || true
        ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU0C Boost' '0' || true
        # pipewire НЕ перезапускаем: его рестарт рвёт PulseAudio-сессию Chromium,
        # audio service не переподключается и теряет звук до перезапуска браузера.
        # wireplumber перерегистрирует ALSA-узлы в PipeWire-графе после rebind.
        # Ждём появления sink, затем перезапускаем pipewire-pulse — это закрывает
        # стухшую PA-сессию и Chromium переподключается к живому сокету.
        ${pkgs.systemd}/bin/loginctl list-users --no-legend | ${pkgs.gawk}/bin/awk '{print $2}' | while read -r user; do
          uid=$(${pkgs.coreutils}/bin/id -u "$user" 2>/dev/null) || continue
          ${pkgs.systemd}/bin/systemctl --user -M "$user@" restart wireplumber.service 2>/dev/null || true
          for i in $(${pkgs.coreutils}/bin/seq 1 60); do
            XDG_RUNTIME_DIR=/run/user/$uid \
              ${pkgs.pulseaudio}/bin/pactl list sinks short 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q . && break
            ${pkgs.coreutils}/bin/sleep 0.5
          done
          ${pkgs.systemd}/bin/systemctl --user -M "$user@" restart pipewire-pulse.service 2>/dev/null || true
        done
      '';

      # SoundWire microphone fix — CyberT3C approach (rt714 codec, XPS 13 Plus 9320)
      systemd.services.xps-mic-fix = {
        after = [ "sound.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          # Workaround: ALSA can fail hard if /var/lib/alsa/card0.conf.d/ctl-remap.conf
          # exists as a stale symlink into a GC'd /nix/store path.
          mkdir -p /var/lib/alsa/card0.conf.d
          if [ -L /var/lib/alsa/card0.conf.d/ctl-remap.conf ] && [ ! -e /var/lib/alsa/card0.conf.d/ctl-remap.conf ]; then
            rm -f /var/lib/alsa/card0.conf.d/ctl-remap.conf
          fi
          if [ ! -e /var/lib/alsa/card0.conf.d/ctl-remap.conf ]; then
            : > /var/lib/alsa/card0.conf.d/ctl-remap.conf
          fi

          # Wait for card 0 to become available (SOF firmware load can take a few seconds)
          for i in $(seq 1 30); do
            ${pkgs.alsa-utils}/bin/amixer -c 0 info &>/dev/null && break
            ${pkgs.coreutils}/bin/sleep 0.5
          done

          # Disable SoundWire device power management
          for dev in /sys/bus/soundwire/devices/*/power/control; do
            echo on > "$dev" || true
          done

          # Route ADC 22 to DMIC1
          ${pkgs.alsa-utils}/bin/amixer -c 0 set 'rt714 ADC 22 Mux' 'DMIC1' || true
          # Enable capture path (PGA5.0 + FU02, used by UCM)
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='PGA5.0 5 Master Capture Switch' 'on,on' || true
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Switch' 'on' || true
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Volume' '70' || true
          # Set boost
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU0C Boost' '0' || true
        '';
      };
    };
}
