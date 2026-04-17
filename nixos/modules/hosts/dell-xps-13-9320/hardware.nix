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

      # Latest kernel required for ipu6ep camera and SoundWire mic on XPS 13 Plus 9320
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

      # intel_int3472: add GPIO type 0x02 (strobe) for ov01a10 sensor (XPS 13 Plus 9320)
      # Without this patch the kernel logs "GPIO type 0x02 unknown" and camera initialises
      # with wrong colours (red tint) because the strobe GPIO is never configured.
      boot.kernelPatches = [
        {
          name = "int3472-gpio-strobe";
          patch = ./intel-int3472-gpio-type.patch;
        }
      ];

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

      # Fix SOF audio (SoundWire rt714 mic noise) after S4 hibernate.
      # Root cause: sof-audio-pci-intel-tgl restores DSP state from hibernate snapshot but
      # SoundWire codec rt714 is not properly re-enumerated → mic produces noise instead of voice.
      # Fix: force rebind of PCI device to reload DSP firmware + re-enumerate SoundWire codecs.
      #
      # NOTE: Camera (ov01a10 via intel_vsc/IVSC) cannot be recovered after S4 hibernate without
      # a cold reboot. The IVSC chip requires hardware power cycle — vsc-tp firmware wakeup times
      # out (-ETIMEDOUT) even after USB LJCA rebind or full USB device-level rebind (3-8).
      powerManagement.resumeCommands = ''
        echo "0000:00:1f.3" > /sys/bus/pci/drivers/sof-audio-pci-intel-tgl/unbind || true
        ${pkgs.coreutils}/bin/sleep 1
        echo "0000:00:1f.3" > /sys/bus/pci/drivers/sof-audio-pci-intel-tgl/bind || true
        # Wait for SOF firmware load + SoundWire rt714 re-enumeration (~5s)
        ${pkgs.coreutils}/bin/sleep 5
        # Reapply rt714 ALSA routing (lost after SOF rebind)
        for dev in /sys/bus/soundwire/devices/*/power/control; do
          echo on > "$dev" || true
        done
        ${pkgs.alsa-utils}/bin/amixer -c 0 set 'rt714 ADC 22 Mux' 'DMIC1' || true
        ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='PGA5.0 5 Master Capture Switch' 'on,on' || true
        ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Switch' 'on' || true
        ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Volume' '70' || true
        ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU0C Boost' '0' || true
        ${pkgs.systemd}/bin/loginctl list-users --no-legend | ${pkgs.gawk}/bin/awk '{print $2}' | while read -r user; do
          ${pkgs.systemd}/bin/systemctl --user -M "$user@" restart wireplumber.service 2>/dev/null || true
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
          ${pkgs.alsa-utils}/bin/amixer -c 0 set 'rt714 ADC 22 Mux' 'DMIC1'
          # Enable capture path (PGA5.0 + FU02, used by UCM)
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='PGA5.0 5 Master Capture Switch' 'on,on'
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Switch' 'on'
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU02 Capture Volume' '70'
          # Set boost
          ${pkgs.alsa-utils}/bin/amixer -c 0 cset name='rt714 FU0C Boost' '0'
        '';
      };
    };
}
