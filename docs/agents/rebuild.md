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

## Build error diagnostics

- Deep nix type errors: eval the real config path instead of
  transcribing the attrset to /tmp:
  `nix eval --impure .#nixosConfigurations.raimguzhinov.config.<failing path>`.
  It evaluates the whole configuration, so expect several minutes
  (use `--json` to inspect lists and attrsets).
- `definition N-entry M ... is not of type ...` — M is the 1-based
  index of the bad element in an N-element list definition.
- Long builds: `... 2>&1 | tee /tmp/build.log` so the output survives
  an interrupted command.
