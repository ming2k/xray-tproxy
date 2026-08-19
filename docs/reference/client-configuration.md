# Client Configuration Reference

Lookup for the Xray client config. The template lives at
[xray-config/client/config-example.json](../../xray-config/client/config-example.json);
the deployed copy is `/etc/xray/config.json`. The service loads every
`*.json` in `/etc/xray/` (`-confdir`) and merges them.

## Placeholders

Replace every placeholder before starting the service.

| Placeholder | Meaning | Where to get it |
|-------------|---------|-----------------|
| `<SERVER_IP:...>` | Server public IP | Your server provider |
| `<UUID:...>` | VLESS user ID | The `id` field in the server config |
| `<SERVER_NAME:...>` | REALITY camouflage SNI | The server `serverNames` entry |
| `<PUBLIC_KEY:...>` | REALITY public key | Public half of `xray x25519` on the server |
| `<SHORT_ID:...>` | REALITY short ID | One of the server `shortIds` |

Also adjust `"address": "192.168.0.1"` in `dns.servers` when the LAN
gateway has a different address.

## Inbound

| Key | Value | Effect |
|-----|-------|--------|
| `protocol` | `dokodemo-door` | Accepts intercepted traffic |
| `port` | `12345` | Matches `XRAY_TPROXY_PORT` in the nftables rules |
| `settings.followRedirect` | `true` | Honors the kernel redirect |
| `streamSettings.sockopt.tproxy` | `"tproxy"` | Enables TProxy socket mode |
| `sniffing.enabled` | `true` | Reads HTTP Host / TLS SNI / QUIC SNI |
| `sniffing.destOverride` | `["http", "tls", "quic"]` | Dials the sniffed domain instead of the original IP |

## Local SOCKS Inbound

A loopback-only SOCKS5 endpoint exists for applications that cannot be
classified by sniffing (for example `git` or `ssh`); point them at it with
their own proxy settings.

| Key | Value | Effect |
|-----|-------|--------|
| `listen` / `port` | `127.0.0.1:1080` | Loopback only; no LAN exposure |
| `protocol` / `settings.auth` | `socks` / `noauth` | SOCKS5 with UDP support |
| `sniffing.destOverride` | `["http", "tls", "quic"]` | Same domain-dialing behavior as the TProxy inbound |

Usage examples: `git config --global http.proxy socks5h://127.0.0.1:1080`,
`ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:1080 %h %p' host`.

## Outbounds

| Tag | Protocol | Purpose |
|-----|----------|---------|
| `proxy` | `vless` (REALITY, `xtls-rprx-vision`) | Remote server |
| `direct` | `freedom` | Local/direct forwarding |
| `dns-out` | `dns` | Xray internal DNS loopback |
| `blocked` | `blackhole` | Drop |

Every outbound sets `streamSettings.sockopt.mark: 2`, which matches
`BYPASS_MARK` in the nftables rules so Xray's own connections are never
re-intercepted. Outbounds also configure `tcpKeepAliveIdle: 15` and `tcpKeepAliveInterval: 5`
to quickly prune stale sockets after sleep/wake or network interface switches.

## Routing Rules

`routing.domainStrategy` is `IPIfNonMatch`. Rules evaluate top to bottom;
first match wins.

| Order | Match | Outbound |
|-------|-------|----------|
| 1 | `inboundTag: all-in, socks-in, port: 53` | `dns-out` — Smart DNS resolution |
| 2 | `ip: <SERVER_IP>` | `direct` — never proxy the proxy |
| 3 | `protocol: bittorrent` | `direct` |
| 4 | `ip: geoip:private` | `direct` |
| 5 | `domain: geosite:google, geosite:openai, geosite:anthropic, domain:z.ai` | `proxy` — explicit proxy overrides before domestic list |
| 6 | `domain: geosite:private, geosite:cn, captive portal probes` | `direct` |
| 7 | `ip: geoip:cn` | `direct` |
| 8 | `network: tcp,udp` (everything else) | `proxy` |

## Built-In DNS

Xray uses its own `dns` module for Smart DNS resolution (see [DNS](../explanation/dns.md)).

| Server | Used for | Verification / Notes |
|--------|----------|----------------------|
| `localhost` (system resolver / `127.0.0.53`) | `geosite:private`, `domain:local`, `domain:lan`, captive portal probes | `skipFallback: true` — pinned to its domains, never joins the fallback chain. Do not use `finalQuery: true` here: it truncates the fallback list at position 0 and kills resolution for every domain not present in the geosite lists |
| `https://1.1.1.1/dns-query` (Cloudflare DoH via `proxy`) | `geosite:geolocation-!cn`, `geosite:google`, `geosite:openai`, `geosite:anthropic`, `geosite:github`, `domain:z.ai` | Encrypted inside proxy tunnel; must be listed before `223.5.5.5`, and evaluated before `geosite:cn` to prevent overseas/hybrid AI domains from triggering `expectedIPs` drops |
| `223.5.5.5` (AliDNS) | `geosite:cn` | answers must match `geoip:cn` |
| `https://1.1.1.1/dns-query` (Cloudflare DoH via `proxy`) | Default fallback | Encrypted inside proxy tunnel |

`localhost` automatically queries whatever upstream DNS is assigned by DHCP to the current Wi-Fi/Ethernet link, enabling captive portal login detection on any network without manual reconfiguration.

`dns.queryStrategy` is `UseIPv4`: prioritizes IPv4 resolution.
