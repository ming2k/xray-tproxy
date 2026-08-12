# Captive Portals

Public Wi-Fi hotspots require a web login before they open access. This
page explains why such networks conflict with transparent proxying in
general, and why this setup does not.

## How Portals Redirect Clients

Before authentication, the hotspot gateway runs a **walled garden**: it
blocks all traffic except DNS and its own login server. To send the client
to the login page, the gateway abuses one of two cleartext channels:

- **DNS spoofing** — every DNS answer points at the login server,
  regardless of the queried name;
- **HTTP interception** — the gateway answers any plain HTTP request with
  a `302` redirect to the login page.

HTTPS cannot be hijacked either way: certificate validation rejects the
forged response, and HSTS prevents bypassing it. Phones therefore probe a
known plain-HTTP URL after connecting (Apple's `hotspot-detect`,
Android's `generate_204`, Firefox's `detectportal.firefox.com`) and open
whatever the hijack returns. A newer standard, RFC 8908/8910, advertises
the login API directly in DHCP and removes the need for hijacking, but
deployment is still rare.

## Why TProxy Breaks The Flow

A naive TProxy setup intercepts the probe traffic before it leaves the
host. The gateway then never sees a naked HTTP request to hijack, and the
proxy tunnel itself cannot help: the walled garden blocks the proxy server
too, so the probe hangs. Two independent hijackers fight over the same
traffic, and the local one wins while being the one that cannot work
pre-auth.

## How This Setup Avoids The Conflict

- The nftables rules leave TCP port 80 direct
  (`tcp dport 80 return`). The gateway always sees naked HTTP and can
  hijack it, exactly as on a phone. Proxying port 80 would buy no
  confidentiality — HTTP is plaintext by design — so nothing of value is
  lost.
- DNS (port 53) also stays direct, so the gateway's DNS answers — real or
  spoofed — reach applications unmodified. Pre-auth resolution can be
  slow, because the walled garden rate-limits or drops some queries, but
  it is not intercepted by the proxy layer.

With both channels intact, any plain-HTTP request triggers the hijack;
opening one in the browser is all the detection the flow needs. Usage is
documented in
[How to Use Captive Portal Networks](../how-to/use-captive-portal-networks.md).

## Remaining Limitation

A few portals host the login page on a public HTTPS address (some
commercial SaaS providers). The hijacked probe redirects the browser to an
HTTPS URL on a public IP, which still goes through the proxy and cannot
connect pre-auth. No static rule set can enumerate those providers in
advance, so the fallback is operational: stop `xray-tproxy.service` for
the login, start it again afterwards. The unit's `ExecStopPost` teardown
makes that safe and complete; see
[Architecture](architecture.md#component-ownership).
