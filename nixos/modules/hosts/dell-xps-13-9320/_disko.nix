# Declarative disk layout for NixOS installation.
# Used only by the install script (disko CLI), NOT as a NixOS module.
# nixos-generate-config writes fileSystems to hardware-configuration.nix.
#
# Layout: GPT → ESP (512M) + swap (32G) + LUKS2 → btrfs (/root, /home, /nix)
# Swap is outside LUKS for simple hibernation support (resumeDevice = true).
# Adjust swap size to match your RAM.
{
  lib,
  disk ? "/dev/disk/by-diskseq/1",
  ...
}:
{
  disko.devices = {
    disk.main = {
      device = disk;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            size = "32G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
