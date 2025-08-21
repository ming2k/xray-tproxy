# XRay TProxy Guidebook

This is a xray tranparent proxy client configuration solution for linux.

## Prerequiste

To apply this project's solution, please make sure the following related utils are adopted:
- xray
- systemd
- `iproute2` package(`ip` command included package)
- `procps-ng` package(`sysctl` command included package)
- nftables

## How to Apply the Project

Allow system network forwarding:

```sh
sudo ./ip-forward-config.sh
```

Config NFTables and Routing:

```sh
sudo bash -c '[ ! -d "/etc/nftables" ] && mkdir -p "/etc/nftables" && cp ./xray-tproxy.nft /etc/nftables/xray-tproxy.nft'
sudo cp ./xray-tproxy.nft 
sudo cp ./xray-tproxy-network.service /etc/systemd/system/xray-tproxy-network.service
```

Please refer to the template to create a usable xray configuration file:

```sh
cp ./config.json.exmaple ./config.json && $EDITOR ./config.json
# Optinal: test your config files
# xray -test -config ./config.json
```

Start your xray, no matter using systemd or mannual, please specified the above config for xray.

Follow the conventions, xray installed via distro package manager includes the service which set `ExecStart=/usr/bin/xray run -confdir /etc/xray/`. In this case, I can start xray using the following method:

```sh
sudo cp ./config.json /etc/xray/config.json
systemctl start xray
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




