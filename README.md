# Xray TProxy Guidebook

## What It Is

This project provides a transparent proxy client setup for a single-host
Linux machine using Xray, nftables, and policy routing. Once installed,
all application traffic is routed through Xray according to your rules —
no per-application proxy configuration needed.

It is tuned for a workstation or laptop running `systemd-networkd` and a
local resolver such as `systemd-resolved`:

- **Real-IP Smart DNS Split**: All DNS is handled via Xray DoH; applications receive authentic, unpolluted IP addresses without FakeIP subnet anomalies
- **Full TProxy Protection**: Both HTTP (port 80) and HTTPS (port 443) for overseas destinations travel through the proxy tunnel, protecting against ISP hijacking and GFW blocks
- **Captive Portal Compatible**: Wi-Fi portal probes (`geosite:captive-portal`) and LAN destinations remain direct for automatic Wi-Fi login popups
- **Root Process Proxying**: `sudo apt update`, `docker pull`, and admin processes are transparently proxied according to Xray routing rules
- **Resilient Policy Routing**: The fwmark policy rule survives suspend/resume cycles because `systemd-networkd` owns it


## Quick Start

Run from the repository root:

```sh
sudo useradd --system --no-create-home --shell /usr/bin/nologin xray
sudo install -Dm644 ./xray-tproxy.nft /etc/nftables/xray-tproxy.nft
sudo install -Dm644 ./xray-tproxy.service /etc/systemd/system/xray-tproxy.service
sudo install -Dm644 ./xray-tproxy.service.d/geo-assets.conf /etc/systemd/system/xray-tproxy.service.d/geo-assets.conf
sudo install -d /etc/systemd/network/20-wireless.network.d
sudo install -m644 ./xray-policy.conf /etc/systemd/network/20-wireless.network.d/xray-policy.conf
sudo install -d /etc/xray
sudo cp ./xray-config/client/config-example.json /etc/xray/config.json
sudoedit /etc/xray/config.json          # fill in every <PLACEHOLDER:...>
sudo systemctl reload systemd-networkd && sudo networkctl reconfigure wlan0
sudo systemctl daemon-reload
sudo systemctl enable --now xray-tproxy.service
```


Adjust the `.network.d/` path to the `.network` file that manages your
uplink. For prerequisites, per-step explanations, and optional parts, see
[How to Install and Start the Transparent Proxy](docs/how-to/install-and-start.md).

## Documentation

See the [Documentation Index](docs/index.md). Frequently used pages:

- [How to Verify the Setup](docs/how-to/verify-the-setup.md)
- [How to Use Captive Portal Networks](docs/how-to/use-captive-portal-networks.md)
- [Client Configuration Reference](docs/reference/client-configuration.md)
- [Architecture](docs/explanation/architecture.md)
