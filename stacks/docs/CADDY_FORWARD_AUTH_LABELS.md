# CADDY_FORWARD_AUTH_LABELS.md

## Goal

Gate specific app routes behind Authentik using forward-auth, per-app opt-in.

You MUST have:
- Authentik running
- A Proxy Provider + Application created for the app
- An Authentik proxy outpost deployed

The outpost exposes an endpoint like:
- http://<outpost-container>:9000/outpost.goauthentik.io/auth/caddy

The container name and port depend on how you deploy the outpost.

## Reference Caddyfile (what we want)

```
komodo.in.hypyr.space {
  forward_auth http://authentik-outpost:9000 {
    uri /outpost.goauthentik.io/auth/caddy
    copy_headers X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid
  }

  reverse_proxy core:30160
}
```

## Template A: "single site" labels (your current pattern)

Some label controllers support forward_auth mappings like:

- caddy: komodo.in.hypyr.space
- caddy.forward_auth: http://authentik-outpost:9000
- caddy.forward_auth.uri: /outpost.goauthentik.io/auth/caddy
- caddy.forward_auth.copy_headers: X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid
- caddy.reverse_proxy: "{{upstreams 30160}}"

If your controller does not support these keys, use Template B.

## Template B: numbered blocks (commonly supported)

- caddy_10: komodo.in.hypyr.space
- caddy_10.forward_auth: http://authentik-outpost:9000
- caddy_10.forward_auth.uri: /outpost.goauthentik.io/auth/caddy
- caddy_10.forward_auth.copy_headers: X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid
- caddy_10.reverse_proxy: "{{upstreams 30160}}"

## Notes / gotchas

1) Network reachability:
- The app and the outpost must share a network where they can resolve each other.
- In your homelab, attach both to `proxy_network`.

2) Break-glass access:
- Keep a direct LAN route (IP:port) or an ungated hostname.

3) DNS:
- Missing DNS records will hit your wildcard fallback and look like auth is broken.
- Verify DNS first.

4) Troubleshooting:
- Check Caddy logs for forward_auth application.
- Check outpost logs for incoming auth checks.
