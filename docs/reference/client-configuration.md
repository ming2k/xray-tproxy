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
| `blocked` | `blackhole` | Drop |

Every outbound sets `streamSettings.sockopt.mark: 2`, which matches
`BYPASS_MARK` in the nftables rules so Xray's own connections are never
re-intercepted.

## Routing Rules

`routing.domainStrategy` is `IPIfNonMatch`. Rules evaluate top to bottom;
first match wins.

| Order | Match | Outbound |
|-------|-------|----------|
| 1 | `ip: <SERVER_IP>` | `direct` — never proxy the proxy |
| 2 | `protocol: bittorrent` | `direct` |
| 3 | `ip: geoip:private` | `direct` |
| 4 | `domain: geosite:private, geosite:cn` | `direct` |
| 5 | `domain: geosite:google, geosite:openai, geosite:anthropic` | `proxy` |
| 6 | `ip: geoip:cn` | `direct` |
| 7 | `network: tcp,udp` (everything else) | `proxy` |

## Built-In DNS

Xray uses its own `dns` module for its own resolution; applications never
see it (see [DNS](../explanation/dns.md)).

| Server | Used for | Verification |
|--------|----------|--------------|
| LAN gateway (`192.168.0.1`) | `geosite:private`, `domain:local`, `domain:lan`, `domain:home.arpa` | `finalQuery: true` |
| `https://223.5.5.5/dns-query` (AliDNS over DoH) | `geosite:cn` | answers must match `geoip:cn` |
| `https://223.5.5.5/dns-query` (AliDNS over DoH) | everything else | — |

Proxied domains are not resolved locally: `sniffing.destOverride` dials
them by name and the server resolves them at its end. Local resolution
only feeds routing classification and `direct` dialing, so a domestic
resolver is sufficient and avoids plaintext foreign DNS queries.

`dns.queryStrategy` is `UseSystem`: address family follows the system.
