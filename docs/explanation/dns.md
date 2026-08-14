# Real-IP DNS Architecture

This setup uses a **Real-IP Smart DNS Split** architecture. All system DNS queries (UDP/TCP port 53) are intercepted by nftables before IP bypass rules and handled by Xray's internal DNS module via the `dns-out` outbound, delivering unpolluted real IP addresses without resorting to FakeIP.

## The DNS Flow

```text
Application -> System Resolver -> Port 53 -> nftables TProxy -> Xray dokodemo-door
                                                                      │
                                                               routing (port 53)
                                                                      │
                                                                      ▼
                                                                  dns-out
                                                                      │
                                                             Xray DNS Module
                                          ┌───────────────────────────┼───────────────────────────┐
                                          ▼                           ▼                           ▼
                                  Portal & Local Domains        Domestic Domains           Foreign Domains
                                 (localhost / system resolver)      (223.5.5.5)         (DoH https://1.1.1.1)
                                          │                           │                           │
                                   DHCP DNS / Portal IP       Real domestic IP            Real overseas IP
```

## How Real-IP DNS Split Works

1. **System DNS Interception**:
   Applications send DNS queries (port 53) to the local resolver or ISP DNS as usual. nftables intercepts all port 53 traffic before private IP bypass rules and redirects queries to Xray's `all-in` inbound. A routing rule matches `port: 53` and sends queries to `"outboundTag": "dns-out"`.

2. **Smart DNS Routing inside Xray**:
   - **Local & Captive Portal Domains** (`geosite:private`, `domain:local`, captive portal probe domains): Resolved via `localhost` (`systemd-resolved` / `127.0.0.53`), which forwards dynamically to the current uplink's DHCP-assigned DNS. On captive portal networks pre-authentication, this resolves the portal login server immediately.
   - **Foreign, Blocked & Hybrid/AI Domains** (`geosite:geolocation-!cn`, `geosite:google`, `geosite:openai`, `geosite:anthropic`, `domain:z.ai`): Evaluated before `geosite:cn` and resolved via encrypted **DNS-over-HTTPS (DoH)** (e.g. `https://1.1.1.1/dns-query`) through the `proxy` outbound. This ensures clean resolution and prevents dual-homed or overseas-backed services (like `z.ai`) from triggering `expectedIPs: ["geoip:cn"]` dropouts.
   - **Domestic Domains** (`geosite:cn`): Resolved via fast domestic DNS (`223.5.5.5`) with `expectedIPs: ["geoip:cn"]`. Applications receive authentic domestic IP addresses, guaranteeing optimal CDN routing.
   - **Fallback**: Any unmatched domain defaults to encrypted DoH (`https://1.1.1.1/dns-query`).

3. **No FakeIP Pollution**:
   Applications receive **real overseas IP addresses** (e.g. `142.250.x.x` for Google).
   - Tools like `ping`, `dig`, `nslookup`, `traceroute`, and `ss` display authentic IP addresses.
   - Debugging, development environments, P2P/WebRTC, and local network discovery tools continue to work natively without FakeIP subnet anomalies (`198.18.x.x`).

4. **TLS/HTTP Sniffing Backup**:
   For TLS/HTTP/QUIC traffic, Xray's `sniffing.destOverride` continues to inspect SNI and Host headers (`routeOnly: true`), ensuring domain-based routing decisions remain accurate regardless of client IP resolution.

