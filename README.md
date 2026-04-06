# XRay TProxy Guidebook

This is a xray tranparent proxy client configuration solution for linux.

This example is tuned for a single-host Linux client:
- DNS stays on a local resolver such as `systemd-resolved`, `dnsmasq`, or `smartdns`
- TProxy only intercepts application traffic
- Xray built-in DNS is still used for Xray's own routing decisions

## Prerequiste

To apply this project's solution, please make sure the following related utils are adopted:
- xray
- systemd
- `iproute2` package(`ip` command included package)
- `procps-ng` package(`sysctl` command included package)
- nftables

## How to Apply the Project

1. Allow system network forwarding:
    ```sh
    sudo ./ip-forward-config.sh
    ```

2. Config NFTables and Routing:
    ```sh
    sudo bash -c '[ ! -d "/etc/nftables" ] && mkdir -p "/etc/nftables" && cp ./xray-tproxy.nft /etc/nftables/xray-tproxy.nft'
    sudo cp ./xray-tproxy-network.service /etc/systemd/system/xray-tproxy-network.service
    ```
3. Config Xray Service:
    You can use the service from the package, and I still provide the template for refering to prevent any unexpected thing.

4. Config Xray, please refer to the template to create a usable xray configuration file:
    ```sh
    cp ./xray-config/client/config-example.json ./config.json && $EDITOR ./config.json
    # Optinal: test your config files
    # xray -test -config ./config.json
    ```

5. Point your system resolver to a local DNS stub. On a `systemd-resolved` host:
    ```sh
    sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    resolvectl status
    ```

6. Start your xray, xray-tproxy-network services:
    ```sh
    sudo systemctl enable --now xray xray-tproxy-network
    ```

---

It is functional but still needs improvement.

If you are using `systemd-networkd`, you will find that `ip rule` is gone after resuming from suspend. This is because that `systemd-networkd` reinitialize it.

So you need to persist the config, the following is a recommended solution.

```shell
sudo nvim /etc/systemd/network/wlan0.network
```

Add the following config:

```config
# ...
[RoutingPolicyRule]
# For XRay TProxy
FirewallMark=1
Table=100
```

Please replace NIC name with yours, Then

```shell
sudo systemctl reload systemd-networkd
```

## Operating Mechanism

Step 1 - Traffic Hijacking: When your app tries to connect to google.com, the Linux firewall catches the packet before it leaves your computer and puts a special "mark" on it.

Step 2 - Routing Trick: A special routing rule says "any packet with this mark should be delivered to localhost instead of the real internet." This fools the kernel into thinking google.com is actually a service running on your own computer.

Step 3 - Proxy Intercept: Xray proxy is listening on localhost and receives the packet. Importantly, it can still see that the original destination was google.com (not localhost), so it knows where the app really wanted to go.

Step 4 - Smart Forwarding: Xray looks at the destination and decides: should this go through a VPN tunnel, or directly to the internet? Then it forwards the traffic accordingly and sends the response back to your app.

The Magic: Your application thinks it connected directly to google.com and has no idea a proxy was involved. Meanwhile, Xray secretly routed the traffic through whatever path you configured (VPN, direct, blocked, etc).

Key Insight: By combining packet marking with custom routing rules, we can intercept traffic at the kernel level while preserving all the original connection information, making the proxy completely invisible to applications.

### Outbound Traffic Flow

```txt
[Application] → [OUTPUT chain] → [Policy Routing] → [Loopback Interface] → [Xray Proxy]
      ↓              ↓                ↓                    ↓                  ↓
   Generates     Packet gets      fwmark=1 packets     External IPs        Proxy processes
   request to    marked with      routed via table     delivered as        and forwards
   8.8.8.8       fwmark=1         100 to loopback      "local" services    to real 8.8.8.8
                     ↓                ↓                    ↓
                TPROXY target    ip route local       Kernel delivers to
                preserves        0.0.0.0/0 dev lo     proxy on lo:12345
                original dest    makes all IPs        with original dest
                                "local"               info preserved
```


### DNS

System DNS and Xray DNS serve different roles in this example:

- System DNS:
  applications read `/etc/resolv.conf` and query a local resolver
- Xray built-in DNS:
  Xray uses its own `dns.servers` to evaluate routing rules such as `geosite:cn`, `geosite:google`, and private-domain handling

Recommended flow:

```txt
Application -> /etc/resolv.conf -> local resolver
           -> answer returned to application

Application traffic -> nft tproxy rules -> xray:12345 [all-in]
                    -> Xray routing
                    -> direct / proxy
```

Do not transparently hijack all `53` traffic into Xray unless you deliberately want Xray to become the system-wide DNS server. On a normal single-host client, that usually breaks LAN DNS semantics, private PTR lookups, and local domain handling.

