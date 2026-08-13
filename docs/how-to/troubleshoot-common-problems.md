# How to Troubleshoot Common Problems

Match your symptom and apply the fix.

## Symptom Table

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Everything goes direct after suspend/resume | networkd reconfigured the uplink and dropped the policy rule | `sudo networkctl reconfigure wlan0`; the drop-in reapplies the rule |
| Service runs but nft counters stay at 0 | policy rule or table-110 route missing | check `ip rule show` and `ip route show table 110` |
| Xray fails to start | bad config, missing geodata, or missing log directory | `sudo -u xray xray -test -config /etc/xray/config.json`; read the journal |
| Service fails with `status=217/USER` | the `xray` user does not exist | `sudo useradd --system --no-create-home --shell /usr/bin/nologin xray` |

| `geoip:cn` / `geosite:cn` rules never match | `geoip.dat` / `geosite.dat` not found | install the `geo-assets.conf` drop-in; see [Install the nftables Rules and the Service Unit](install-and-start.md#install-the-nftables-rules-and-the-service-unit) |
| Public Wi-Fi login page never opens | portal login page hosted on public HTTPS | see [How to Use Captive Portal Networks](use-captive-portal-networks.md) |
| Slow DNS right after joining a hotspot | walled garden blocks resolution pre-auth | expected; resolves itself after portal login |
| Blocked sites unreachable on a trusted network | DoH server unreachable or routing rule mismatch | check `journalctl -u xray-tproxy` and verify `dns-out` tag; see [DNS](../explanation/dns.md) |


## Check the Suspend/Resume Case

After a suspend cycle, compare these three:

```sh
sudo nft list tables             # tables still present
ip route show table 110          # local default still present
ip rule show                     # fwmark 0x1 lookup 110 missing?
```

A missing `fwmark` rule with the other two intact is the signature of the
networkd reconfiguration problem. The fix is the drop-in described in
[How to Install and Start the Transparent Proxy](install-and-start.md#install-the-policy-rule-drop-in);
background is in [Architecture](../explanation/architecture.md#suspend-and-resume).
