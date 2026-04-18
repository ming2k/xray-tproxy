# Xray TProxy Guidebook

This project provides a transparent proxy client setup for a single-host Linux machine using Xray, nftables, and policy routing.

This layout is tuned for a workstation or laptop:
- system DNS stays on a local resolver such as `systemd-resolved`, `dnsmasq`, or `smartdns`
- nftables only intercepts application traffic
- Xray built-in DNS is still used for Xray's own routing decisions
- `systemd-networkd` owns the `fwmark -> routing table` policy rule when networkd manages the uplink

## Prerequisites

Make sure the host already has:
- `xray`
- `systemd`
- `iproute2`
- `procps-ng`
- `nftables`

## Files In This Repo

- [README.md](README.md)
- [xray-tproxy.nft](xray-tproxy.nft)
- [xray-tproxy.service](xray-tproxy.service)
- [xray-policy.conf](xray-policy.conf)
- [ip-forward-config.sh](ip-forward-config.sh)

## Recommended Ownership

Use this ownership split:

- `systemd-networkd` manages policy routing rules such as `fwmark 1 -> table 110`
- `xray-tproxy.service` manages Xray itself, the dedicated local route in table `110`, and nftables tables `xray_v4` and `xray_v6`

This avoids a common suspend/resume problem on `systemd-networkd` systems: networkd may reconfigure the interface and remove foreign `ip rule` entries, while leaving nftables and the custom route table intact.

## Routing Table Choice

This guide uses routing table `110` dedicated to Xray.

Add a name for readability:

```sh
echo '110 xray' | sudo tee -a /etc/iproute2/rt_tables
```

The alias is optional. The actual config in this repo uses the numeric table id `110` for predictability.

## How To Apply

1. Enable forwarding:

```sh
sudo ./ip-forward-config.sh
```

2. Install the nftables rules and service unit:

```sh
sudo install -Dm644 ./xray-tproxy.nft /etc/nftables/xray-tproxy.nft
sudo install -Dm644 ./xray-tproxy.service /etc/systemd/system/xray-tproxy.service
```

3. If your uplink is managed by `systemd-networkd`, install the policy rule drop-in under the `.network.d/` directory of the `.network` file that manages that uplink.

For example, if Wi-Fi is managed by `/etc/systemd/network/20-wireless.network`:

```sh
sudo install -d /etc/systemd/network/20-wireless.network.d
sudo install -m644 ./xray-policy.conf /etc/systemd/network/20-wireless.network.d/xray-policy.conf
```

If your uplink uses a different file such as `25-wlan.network` or `10-eth.network`, place the drop-in under that matching `.network.d/` directory instead.

4. Create your Xray client config:

```sh
cp ./xray-config/client/config-example.json ./config.json
$EDITOR ./config.json
# Optional:
# xray -test -config ./config.json
```

5. Point the system resolver to a local DNS stub. On a `systemd-resolved` host:

```sh
sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
resolvectl status
```

6. Reload networkd if you installed the policy rule drop-in:

```sh
sudo systemctl reload systemd-networkd
sudo networkctl reconfigure wlan0
```

Replace `wlan0` with the actual uplink interface if needed.

7. Reload systemd and start the service:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now xray-tproxy.service
```

## `systemd-networkd` Policy Rule

The sample [xray-policy.conf](xray-policy.conf) contains:

```ini
[RoutingPolicyRule]
Family=ipv4
FirewallMark=1
Table=110
Priority=32765

[RoutingPolicyRule]
Family=ipv6
FirewallMark=1
Table=110
Priority=32765
```

Use the numeric table id in the networkd file even if `/etc/iproute2/rt_tables` defines `110 xray`.

## Verification

After bringing the service up, check:

```sh
ip rule show
ip -6 rule show
ip route show table 110
ip -6 route show table 110
sudo nft list tables
```

Expected state:

- `ip rule show` contains `fwmark 0x1 lookup 110`
- `ip -6 rule show` contains `fwmark 0x1 lookup 110`
- table `110` contains `local default dev lo`
- nftables contains `table ip xray_v4` and `table ip6 xray_v6`

## Suspend And Resume

On `systemd-networkd` hosts, a suspend/resume cycle may reconfigure the uplink and remove foreign `ip rule` entries.

Typical symptom:

- `sudo nft list tables` still shows `xray_v4` and `xray_v6`
- `ip route show table 110` still shows `local default dev lo scope host`
- `ip rule show` no longer shows `fwmark 0x1 lookup 110`

That is why this guide puts the policy rule in `systemd-networkd` instead of adding and deleting it from `xray-tproxy.service`.

## Operating Mechanism

Step 1: nftables marks intercepted application packets with `fwmark=1`.

Step 2: policy routing sends packets marked with `1` into routing table `110`.

Step 3: table `110` contains a `local` route to loopback, so the kernel delivers the packet to Xray while preserving the original destination.

Step 4: Xray inspects the original destination and forwards the traffic according to your routing rules.

### Outbound Traffic Flow

```txt
[Application] -> [OUTPUT chain] -> [Policy Routing] -> [Loopback Interface] -> [Xray]
      |               |                  |                    |                |
   Creates         nftables          fwmark=1 lookup      table 110        Xray reads
   traffic         sets mark         110 selects          local route       original dst
                                      table 110           delivers to lo    and forwards
```

### DNS

System DNS and Xray DNS serve different roles:

- system DNS:
  applications read `/etc/resolv.conf` and query a local resolver
- Xray built-in DNS:
  Xray uses its own `dns.servers` for routing decisions such as `geosite:cn`, `geosite:google`, and private-domain handling

Recommended flow:

```txt
Application -> /etc/resolv.conf -> local resolver
           -> answer returned to application

Application traffic -> nft tproxy rules -> xray:12345 [all-in]
                    -> Xray routing
                    -> direct / proxy
```

Do not transparently hijack all port `53` traffic into Xray unless you deliberately want Xray to act as the system-wide DNS server.
