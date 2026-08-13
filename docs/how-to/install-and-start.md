# How to Install and Start the Transparent Proxy

Install the full setup on a bare system. For the shortest command-only
path, follow the [Quick Start](../../README.md#quick-start); this guide
explains each step and covers the optional parts.

## Prerequisites

Install these packages: `xray`, `nftables`, `iproute2`, `systemd`,
`procps-ng`.

You also need:

- `geoip.dat` and `geosite.dat`, because the routing rules reference
  `geoip:cn`, `geosite:cn`, and related groups. The repo ships a service
  drop-in that points Xray at them (see the install step below); adjust
  the path inside if your data files live elsewhere.

- a VLESS+Reality server. See
  [xray-config/server/reality-config-example.json](../../xray-config/server/reality-config-example.json)
  if you run your own.
- `systemd-resolved` (or another local resolver) and an uplink managed by
  `systemd-networkd`.

## Create the `xray` System User

The service runs Xray as an unprivileged user with only
`CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW`:

```sh
sudo useradd --system --no-create-home --shell /usr/bin/nologin xray
```

## Install the nftables Rules and the Service Unit

```sh
sudo install -Dm644 ./xray-tproxy.nft /etc/nftables/xray-tproxy.nft
sudo install -Dm644 ./xray-tproxy.service /etc/systemd/system/xray-tproxy.service
sudo install -Dm644 ./xray-tproxy.service.d/geo-assets.conf /etc/systemd/system/xray-tproxy.service.d/geo-assets.conf
```

The drop-in sets `XRAY_LOCATION_ASSET` so Xray finds `geoip.dat` and
`geosite.dat`; adjust the path in
`xray-tproxy.service.d/geo-assets.conf` if your data files live
elsewhere.

## Install the Policy-Rule Drop-In

Install [xray-policy.conf](../../xray-policy.conf) under the `.network.d/`
directory of the `.network` file that manages your uplink:

```sh
sudo install -d /etc/systemd/network/20-wireless.network.d
sudo install -m644 ./xray-policy.conf /etc/systemd/network/20-wireless.network.d/xray-policy.conf
```

Replace `20-wireless.network` with the file that manages your uplink, such
as `25-wlan.network` or `10-eth.network`.

Optionally name routing table `110` for readability:

```sh
echo '110 xray' | sudo tee -a /etc/iproute2/rt_tables
```

The alias is optional; the drop-in uses the numeric id `110` either way.
Then apply the drop-in:

```sh
sudo systemctl reload systemd-networkd
sudo networkctl reconfigure wlan0   # replace with your uplink
```

## Create the Xray Client Config

The service starts Xray with `-config /etc/xray/config.json`. Install the client config:

```sh
sudo install -d /etc/xray
sudo cp ./xray-config/client/config-example.json /etc/xray/config.json
sudoedit /etc/xray/config.json
```

Fill in every `<PLACEHOLDER:...>`; see the placeholder table in the
[Client Configuration Reference](../reference/client-configuration.md#placeholders).
Validate the result before continuing:

```sh
sudo -u xray xray -test -config /etc/xray/config.json
```

The systemd service unit automatically manages `/var/log/xray` directory creation and ownership via `LogsDirectory=xray`.


## Point the System Resolver at the Local Stub

On a `systemd-resolved` host:

```sh
sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
resolvectl status
```

## Start the Service

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now xray-tproxy.service
```

Continue with [How to Verify the Setup](verify-the-setup.md).
