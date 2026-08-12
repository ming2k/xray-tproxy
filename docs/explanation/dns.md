# DNS

Two independent DNS paths exist on the host, and the design keeps them
separate on purpose.

## The Two Paths

- **System DNS** resolves names for applications. Applications read
  `/etc/resolv.conf` and query the local resolver (`systemd-resolved` by
  default). The nftables rules never touch TCP/UDP port 53, so these
  queries always travel directly to the resolver's upstream — typically
  the DHCP-provided server of the current network.
- **Xray built-in DNS** resolves names for Xray itself: routing decisions
  (`geosite:cn` and similar groups need answers to classify) and dialing
  for the `direct` outbound. The `dns.servers` list routes private
  domains to the LAN gateway and everything else to AliDNS over DoH
  (`https://223.5.5.5/dns-query`), with `geosite:cn` answers verified
  against `geoip:cn`. Proxied domains are not resolved locally at all —
  `sniffing.destOverride` dials them by name and the server resolves them
  at its end.

```text
Application -> /etc/resolv.conf -> local resolver -> answer

Application traffic -> nft tproxy -> xray:12345 [all-in]
                    -> Xray routing -> direct / proxy
```

## Why Port 53 Stays Direct

Hijacking all port-53 traffic into Xray would make Xray the system-wide
DNS server. That has three costs this setup avoids:

- the local resolver's per-link split (different DNS per network) and its
  cache are bypassed;
- captive portals rely on answering application DNS queries themselves —
  intercepting those queries breaks portal detection (see
  [Captive Portals](captive-portals.md));
- a misconfigured Xray DNS module takes down name resolution for the
  whole host instead of just the proxy path.

## Poisoned Answers And Sniffing

On untrusted networks the system resolver can receive poisoned answers for
blocked domains. Two mechanisms limit the damage:

- `sniffing.destOverride` lets Xray dial the sniffed TLS SNI / HTTP Host
  domain instead of the original destination IP, so for proxied traffic a
  wrong answer never reaches the wire — the server resolves the name at
  its end.
- Traffic that matches a `direct` rule does dial the resolver-provided
  address, so `direct`-routed domains still depend on system DNS quality.
  The `dns.servers` split keeps Chinese domains on a domestic resolver,
  which is the traffic class that goes `direct`.

This division of labor is why the config's routing rules, the `dns`
module, and the nftables port-53 bypass are designed as one unit; changing
one without the others shifts which failure modes are possible.
