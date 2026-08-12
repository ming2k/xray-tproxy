# How to Verify the Setup

Confirm that interception, policy routing, and Xray forwarding all work
after installation or after changing the nftables rules.

## Check the Static State

```sh
systemctl status xray-tproxy.service
ip rule show                     # expect: fwmark 0x1 lookup 110
ip -6 rule show                  # expect: fwmark 0x1 lookup 110
ip route show table 110          # expect: local default dev lo
sudo nft list tables             # expect: ip xray_v4 and ip6 xray_v6
```

## Check That Traffic Is Intercepted

The nftables rules carry packet counters. Generate some traffic, then
read the table:

```sh
curl -s https://api.ipify.org >/dev/null
sudo nft list table ip xray_v4
```

The counters on the `tproxy` / `meta mark set` rules should grow.

## Check the Forwarding Result

```sh
curl -s https://api.ipify.org    # expect: your server's IP (proxied)
curl -s http://ip.sb             # expect: your real IP (direct)
```

The two commands returning different addresses is expected: TCP port 80
bypasses the proxy by design. See
[Traffic Selection Reference](../reference/traffic-selection.md) for the
full bypass list and [Captive Portals](../explanation/captive-portals.md)
for the reason.

## Check the Logs

```sh
journalctl -u xray-tproxy.service -n 50 --no-pager
sudo tail -n 50 /var/log/xray/error.log
```

If any check fails, go to
[How to Troubleshoot Common Problems](troubleshoot-common-problems.md).
