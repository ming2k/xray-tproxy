# Traffic Selection Reference

Lookup for what the nftables rules in
[xray-tproxy.nft](../../xray-tproxy.nft) intercept and what they bypass.
The tables are `ip xray_v4` and `ip6 xray_v6`; each has a `prerouting`
chain (traffic passing through) and an `output` chain (locally generated
traffic).

## Constants

| Name | Value | Meaning |
|------|-------|---------|
| `XRAY_MARK` | `1` | fwmark on intercepted packets; policy routing sends it to table `110` |
| `BYPASS_MARK` | `2` | fwmark that skips interception; Xray outbounds set it via `sockopt.mark` |
| `XRAY_TPROXY_PORT` | `12345` | Xray `dokodemo-door` inbound port |
| routing table | `110` | Contains `local default dev lo` for mark-1 packets |
| policy rule priority | `32765` | Set by the `systemd-networkd` drop-in |

## Intercepted

Everything not listed under "Bypassed" is redirected to Xray (including System DNS port 53, Plain HTTP port 80, and Root process traffic):

| Chain | Action |
|-------|--------|
| `prerouting` (v4/v6) | `tproxy to 127.0.0.1:12345` / `[::1]:12345`, set mark `1` |
| `output` (v4/v6) | set mark `1`; policy routing delivers to loopback |

## Bypassed (Kernel-Level)

Rules evaluate top to bottom; first match returns from the chain.

| Traffic | Rule | Reason |
|---------|------|--------|
| Reserved ranges (`10/8`, `100.64/10`, `127/8`, `169.254/16`, `172.16/12`, ...; IPv6 ULA/link-local/multicast) | `ip daddr $RESERVED_IP return` (and v6 twin) | Local and non-routable destinations stay direct |
| LAN (`192.168/16`, `fc00::/7`) | `ip daddr 192.168.0.0/16 return` (and v6 twin) | Local network services stay direct |
| Mark-2 packets | `meta mark $BYPASS_MARK return` | Xray's own outbound connections must not loop |
| ICMP / essential ICMPv6 | `ip protocol icmp return`, `icmpv6 type { ... } return` | Ping and neighbor discovery keep working |

Note: Higher-level application traffic (DNS port 53, HTTP port 80, Root processes) is intercepted by nftables and classified by Xray's routing engine (`geosite:cn`, `geosite:captive-portal`, `geoip:private`, etc.).

## Live Inspection

```sh
sudo nft list table ip xray_v4
sudo nft list table ip6 xray_v6
```

Every intercept rule carries a `counter` that increments per matched
packet.

