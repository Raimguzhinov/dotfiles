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
      boot.kernelPackages = pkgs.linuxPackages_latest;

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

      # Zswap: compressed RAM cache in front of disk swap.
      # Pages are compressed in RAM first; cold pages spill to disk swap.
      # Better than zram for systems with physical swap (preserves hibernate).
      # Note: boot.zswap module is not merged in nixpkgs yet (PR #470366),
      # so we use kernel parameters directly.
      boot.kernelParams = [
        "zswap.enabled=1"
        "zswap.compressor=lz4"
        "zswap.max_pool_percent=20"
        "zswap.shrinker_enabled=1"
      ];

      # Low swappiness: prefer keeping processes in RAM, use swap only under pressure.
      boot.kernel.sysctl."vm.swappiness" = 10;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      hardware.enableAllFirmware = true;

      # Persist ALSA mixer state.
      # XPS 9320 SoundWire (rt714) often comes back from S4 with reset controls;
      # restoring the saved ALSA state is a safer fix than PCI unbind/bind.
      hardware.alsa.enablePersistence = true;

      # NixOS' alsa-store fails hard if the state file doesn't exist yet.
      # Create it once at boot to allow subsequent restore/store cycles.
      systemd.services.xps-alsa-bootstrap-state = {
        description = "XPS 9320: bootstrap /var/lib/alsa/asound.state";
        wantedBy = [ "multi-user.target" ];
        after = [ "sound.target" ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = 20;
        };
        script = ''
          set -eu
          mkdir -p /var/lib/alsa
          if [ ! -e /var/lib/alsa/asound.state ]; then
            : > /var/lib/alsa/asound.state
          fi
          # Best-effort: capture current defaults so alsa-store restore has something real.
          ${pkgs.alsa-utils}/bin/alsactl store -gU 2>/dev/null || true
        '';
      };

      # XPS 9320: rt714 capture routing sometimes comes up wrong (e.g. MIC1 + PGA off),
      # which results in silence/white-noise in all apps. Force the known-good route.
      # This is intentionally minimal: no PCI unbind/bind and no PipeWire restarts.
      systemd.services.xps-mic-route = {
        description = "XPS 9320: force rt714 mic routing";
        wantedBy = [
          "multi-user.target"
          "post-resume.target"
        ];
        after = [
          "sound.target"
          "post-resume.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = 30;
        };
        script = ''
          set -eu

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
          for i in $(${pkgs.coreutils}/bin/seq 1 30); do
            ${pkgs.alsa-utils}/bin/amixer -c 0 info &>/dev/null && break
            ${pkgs.coreutils}/bin/sleep 0.5
          done

          # Disable SoundWire device power management
          for dev in /sys/bus/soundwire/devices/*/power/control; do
            echo on > "$dev" || true
          done

          # Route ADC 22 to DMIC1 and enable capture path.
          ${pkgs.alsa-utils}/bin/amixer -c 0 set 'rt714 ADC 22 Mux' 'DMIC1' || true
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='PGA5.0 5 Master Capture Switch' 'on,on' || true
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Switch' 'on' || true
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Volume' '70' || true
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU0C Boost' '0' || true

          # Persist so the next boot/resume starts closer to a good state.
          ${pkgs.alsa-utils}/bin/alsactl store -gU 2>/dev/null || true
        '';
      };

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
            # Ensure the loopback node exists (this module is not auto-loaded).
            # `video_nr=40` is configured via `boot.extraModprobeConfig` above.
            ${pkgs.kmod}/bin/modprobe v4l2loopback 2>/dev/null || true

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

      # Post-resume: rebind the IPU6 PCI device so the kernel driver re-probes
      # and rebuilds the media/V4L2 graph.  Same pattern as the SOF audio rebind
      # fix above (powerManagement.resumeCommands), which works reliably for S4.
      # After rebind, restart camera-setup to recreate /dev/camera-active and
      # camera-bridge so libcamerasrc gets a fresh pipeline.
      systemd.services.xps-camera-post-resume = {
        description = "XPS 9320: rebind IPU6 + restart camera after resume";
        wantedBy = [ "post-resume.target" ];
        after = [ "post-resume.service" ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = 30;
        };
        script = ''
          set -eu

          # Stop the bridge so nothing is holding /dev/video* nodes.
          ${pkgs.systemd}/bin/systemctl stop camera-bridge.service 2>/dev/null || true

          # Find the IPU6 PCI device and rebind its driver.
          for addr in /sys/bus/pci/devices/0000:00:05.0; do
            [ -d "$addr" ] || continue
            drv=$(readlink -f "$addr/driver" 2>/dev/null || true)
            drvname=''${drv##*/}
            [ -n "$drvname" ] || continue
            echo "Rebinding PCI device ''${addr##*/} from driver $drvname"
            echo -n "''${addr##*/}" > /sys/bus/pci/drivers/"$drvname"/unbind || true
            sleep 1
            echo -n "''${addr##*/}" > /sys/bus/pci/drivers/"$drvname"/bind || true
          done

          sleep 2

          # Recreate /dev/camera-active and restart the bridge.
          ${pkgs.systemd}/bin/systemctl restart camera-setup.service 2>/dev/null || true
          ${pkgs.systemd}/bin/systemctl restart camera-bridge.service 2>/dev/null || true
        '';
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

      # Camera recover experiment (post-resume): unloading/reloading camera modules on resume
      # is risky and can destabilize the kernel after S4. Keep it off by default.
      systemd.services.xps-camera-recover = {
        enable = lib.mkDefault false;
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

      # Post-resume: restore ALSA state after S4.
      # This fixes the common case where SoundWire capture controls reset on resume.
      systemd.services.xps-alsa-restore-post-resume = {
        description = "XPS 9320: restore ALSA state after resume";
        wantedBy = [ "post-resume.target" ];
        after = [ "post-resume.service" ];
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = 20;
        };
        script = ''
          set -eu
          ${pkgs.alsa-utils}/bin/alsactl restore -gU || true
        '';
      };

      # Old approach: force-routing with amixer at boot.
      # Keeping it removed in favor of alsactl restore (persistence + post-resume restore).
    };
}
