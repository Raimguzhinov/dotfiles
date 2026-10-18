# nixos-rebuild switch

`sudo` authenticates through the fingerprint reader (fprintd +
polkit-soteria). Run the command yourself:

1. `notify-send "nixos-rebuild switch" "Зайди в сессию и приложи палец к сканеру отпечатка..."`
2. `sleep 1`
3. `sudo nixos-rebuild switch --flake ~/dotfiles/nixos#raimguzhinov`

"Password required" means the fingerprint did not match: repeat with a new
`notify-send`. After the second failure, ask the user to run the command
manually.

The user touches the fingerprint reader. The YubiKey is only for sops
decryption and GPG commit signing.

VM with a GL display:

```bash
nixos-rebuild build-vm --flake ~/dotfiles/nixos#raimguzhinov
./result/bin/run-raimguzhinov-vm -device virtio-vga-gl -display gtk,gl=on
```
