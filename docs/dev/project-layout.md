# Project Layout

Repository tree map and ownership boundaries. User-facing behavior is
documented from the [Documentation Index](../index.md).

## Tree Map

| Path | Purpose |
|------|---------|
| `xray-tproxy.nft` | nftables tables `xray_v4` / `xray_v6`; deployed to `/etc/nftables/` |
| `xray-tproxy.service` | systemd unit; deployed to `/etc/systemd/system/` |
| `xray-tproxy.service.d/` | Unit drop-ins (`geo-assets.conf` sets `XRAY_LOCATION_ASSET`) |
| `xray-policy.conf` | networkd drop-in; deployed under the uplink's `.network.d/` |
| `xray-config/client/` | Client config template |
| `xray-config/client/config-*.json` | Local per-server client configs (real credentials); gitignored |
| `xray-config/server/` | Matching VLESS+Reality server template |
| `docs/` | Documentation; governance in `docs/dev/documentation/` |

## Design References

| Component | Primary reference |
|-----------|-------------------|
| nftables rules | [Traffic Selection Reference](../reference/traffic-selection.md) |
| Client config template | [Client Configuration Reference](../reference/client-configuration.md) |
| Service unit and policy rule | [Architecture](../explanation/architecture.md) |

## Where New Files Go

- New documentation: route it with
  [Routing](documentation/routing.md); never add files to
  `docs/dev/documentation/` itself.
- New config templates: under `xray-config/`, split by `client/` or
  `server/`.
- New operational scripts: repository root, executable, with a
  `sudo`-guard when they need root.
- Diagnostic output (`xray-tproxy-diagnose-*.txt`): never committed;
  covered by `.gitignore`.
