# Declarative disk layout for NixOS installation.
# Used in two ways:
#   1. As a NixOS module (imported in flake.nix) — disk uses default "/dev/disk/by-diskseq/1"
#      (stable paths like /dev/disk/by-partlabel/... are used for the running system)
#   2. By the install script via disko CLI with --arg disk '"/dev/nvme0n1"'
#
# Layout: GPT → ESP (1G) + LUKS2 → LVM pool → swap (32G) + btrfs root
# Adjust swap size to match your RAM for hibernation support.
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
            size = "1G";
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
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };

    lvm_vg.pool = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = "32G";
          content = {
            type = "swap";
            resumeDevice = true; # sets boot.resumeDevice automatically
          };
        };
        root = {
          size = "100%FREE";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
              "@nix" = {
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
}
