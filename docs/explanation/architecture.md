# Architecture

The setup moves application traffic through Xray without any
per-application proxy configuration. Four components cooperate, and each
has exactly one owner.

## Traffic Flow

```text
[Application] -> [OUTPUT chain] -> [Policy Routing] -> [Loopback Interface] -> [Xray]
      |               |                  |                    |                |
   Creates         nftables          fwmark=1 lookup      table 110        Xray reads
   traffic         sets mark         110 selects          local route       original dst
                                      table 110           delivers to lo    and forwards
```

1. nftables marks intercepted application packets with `fwmark=1`.
2. Policy routing sends mark-1 packets into routing table `110`.
3. Table `110` contains a `local` route to loopback, so the kernel
   delivers the packet to Xray while preserving the original destination.
4. Xray inspects the original destination and forwards the traffic
   according to the configured routing rules (`direct` / `proxy` /
   `blocked`).

The exact match/bypass list is in
[Traffic Selection Reference](../reference/traffic-selection.md).

## Component Ownership

| Component | Owner |
|-----------|-------|
| nftables tables `xray_v4` / `xray_v6` | `xray-tproxy.service` (`ExecStartPre` loads, `ExecStopPost` deletes) |
| `local default` routes in table `110` | `xray-tproxy.service` (`ExecStartPre`) |
| `fwmark 1 -> table 110` policy rule | `systemd-networkd` drop-in (`xray-policy.conf`) |
| Xray process | `xray-tproxy.service`, running as the unprivileged `xray` user |

Stopping the service therefore restores plain networking completely: the
unit's `ExecStopPost` removes the nftables tables and flushes table `110`.
This property is what the captive-portal workaround in
[How to Use Captive Portal Networks](../how-to/use-captive-portal-networks.md)
relies on.

## Suspend And Resume

On `systemd-networkd` hosts, a suspend/resume cycle may reconfigure the
uplink and remove foreign `ip rule` entries while leaving nftables tables
and custom route tables intact. The typical symptom after resume:

- `sudo nft list tables` still shows `xray_v4` and `xray_v6`
- `ip route show table 110` still shows `local default dev lo`
- `ip rule show` no longer shows `fwmark 0x1 lookup 110`

Traffic then bypasses the proxy silently. Because the policy rule lives in
a networkd drop-in instead of in the service unit, networkd reapplies the
rule itself whenever it reconfigures the uplink, and
`networkctl reconfigure <uplink>` restores it manually.

## Privilege Boundaries

Xray runs as the dedicated `xray` user with only
`CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW`; it cannot read user home
directories (`ProtectHome=true`). Loop prevention does not depend on the
UID: Xray's own outbound connections carry `sockopt.mark: 2`, which the
nftables rules bypass explicitly. The `meta skuid 0 return` rule in the
`output` chains is an administrative convenience so root shells always
reach the network directly.
