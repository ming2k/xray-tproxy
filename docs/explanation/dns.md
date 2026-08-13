# Real-IP DNS Architecture

This setup uses a **Real-IP Smart DNS Split** architecture. All system DNS queries (UDP/TCP port 53) are intercepted by nftables and handled by Xray's internal DNS module via the `dns-out` outbound, delivering unpolluted real IP addresses without resorting to FakeIP.

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
                                                        ┌─────────────┴─────────────┐
                                                        ▼                           ▼
                                                Domestic / Captive           Foreign Domains
                                                (223.5.5.5 / LAN)         (DoH https://1.1.1.1)
                                                        │                           │
                                                Real domestic IP            Real overseas IP
```

## How Real-IP DNS Split Works

1. **System DNS Interception**:
   Applications send DNS queries (port 53) to the local resolver or ISP DNS as usual. nftables redirects these queries to Xray's `all-in` inbound. A routing rule matches `port: 53` and sends queries to `"outboundTag": "dns-out"`.

2. **Smart DNS Routing inside Xray**:
   - **Domestic & Captive Portal Domains** (`geosite:cn`, `geosite:captive-portal`, `geosite:private`): Resolved via fast domestic DNS (`223.5.5.5` or LAN gateway). Applications receive true domestic IP addresses, guaranteeing optimal CDN routing.
   - **Foreign & Blocked Domains**: Resolved via encrypted **DNS-over-HTTPS (DoH)** (e.g. `https://1.1.1.1/dns-query`) through the `proxy` outbound. GFW cannot poison or eavesdrop on DNS lookups.

3. **No FakeIP Pollution**:
   Applications receive **real overseas IP addresses** (e.g. `142.250.x.x` for Google).
   - Tools like `ping`, `dig`, `nslookup`, `traceroute`, and `ss` display authentic IP addresses.
   - Debugging, development environments, P2P/WebRTC, and local network discovery tools continue to work natively without FakeIP subnet anomalies (`198.18.x.x`).

4. **TLS/HTTP Sniffing Backup**:
   For TLS/HTTP/QUIC traffic, Xray's `sniffing.destOverride` continues to inspect SNI and Host headers (`routeOnly: true`), ensuring domain-based routing decisions remain accurate regardless of client IP resolution.

