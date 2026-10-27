---
name: protei-vpn
description: Bring up the Protei corporate VPN (OpenVPN through NetworkManager). Use when the user asks for the work VPN, or when *.protei.ru hosts (git.protei.ru, uc.protei.ru) fail to resolve or time out.
---

# Protei VPN

The VPN is the NetworkManager connection `raimguzhinov` (`vpn.service-type` `org.freedesktop.NetworkManager.openvpn`). NetworkManager keeps its secrets, so it comes up without a prompt.

1. Check whether it is already up: `nmcli -t -f NAME,TYPE,STATE con show --active`. A `raimguzhinov:vpn:activated` row means the work is done.
2. If Clash Verge runs (`pgrep -af 'clash-verge|mihomo'`), its TUN mode competes with the VPN for routes and DNS. Ask the user whether to stop it before going on.
3. Connect: `nmcli con up raimguzhinov`. The warning about `vpn.secrets.password` and `--ask` is harmless when the next line says the connection is activated.
4. Done when the active list shows `raimguzhinov:vpn:activated` and `ip -br addr` shows `tun0` with an address.

If `nmcli` fails on missing secrets, ask the user to run `! nmcli con up raimguzhinov --ask`. To disconnect: `nmcli con down raimguzhinov`.
