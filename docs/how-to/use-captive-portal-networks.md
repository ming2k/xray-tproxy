# How to Use Captive Portal Networks

Public Wi-Fi hotspots (airports, cafes, hotels) show a web login page
before they open access. This setup keeps that flow working with the
proxy running; background is in
[Captive Portals](../explanation/captive-portals.md).

## Open the Login Page

After connecting to the hotspot, open any plain-HTTP address in your
browser, for example `http://neverssl.com`. The gateway hijacks the
request and redirects it to the login page. Log in as usual; the proxy
needs no changes. If the page does not load immediately, DNS on the
hotspot may still be settling — wait a few seconds and retry.

## Work Around a Stubborn Portal

A few portals host the login page on a public HTTPS address (some
commercial SaaS providers). Pre-auth, HTTPS to a public IP still goes
through the proxy and cannot connect. If the login page does not load,
stop the service briefly:

```sh
sudo systemctl stop xray-tproxy
```

The unit's `ExecStopPost` removes the nftables tables and the table-110
routes, restoring plain networking. Log in, then bring the proxy back:

```sh
sudo systemctl start xray-tproxy
resolvectl flush-caches
```

Flushing the resolver cache removes fake or failed answers cached during
the walled-garden phase.
