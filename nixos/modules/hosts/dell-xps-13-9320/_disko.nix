# Declarative disk layout for NixOS installation.
# Used only by the install script (disko CLI), NOT as a NixOS module.
# nixos-generate-config writes fileSystems to hardware-configuration.nix.
#
# Layout: GPT → ESP (512M) + LUKS2 → btrfs (/root, /home, /nix, /swap)
# Swap is a swapfile inside LUKS; after install set resume_offset from
# `btrfs inspect-internal map-swapfile -r /swap/swapfile`.
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
                  "/swap" = {
                    mountpoint = "/swap";
                    swap.swapfile.size = "32G";
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
