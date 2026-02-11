# CADDY_FORWARD_AUTH_LABELS.md

## Goal

Gate specific app routes behind Authentik using forward-auth, per-app opt-in.

You MUST have:
- Authentik running
- A Proxy Provider + Application created for the app (via blueprint)
- The application assigned to the embedded outpost (via blueprint)

The Authentik server has an embedded outpost that exposes the auth endpoint:
- http://authentik-server:9000/outpost.goauthentik.io/auth/caddy

The `authentik-server` service must be on `proxy_network` so Caddy can reach it.

## Reference Caddyfile (what we want)

```
komodo.in.hypyr.space {
  forward_auth http://authentik-server:9000 {
    uri /outpost.goauthentik.io/auth/caddy
    copy_headers X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid
  }

  reverse_proxy core:30160
}
```

## Template A: Single site labels (caddy-docker-proxy)

```yaml
deploy:
  labels:
    caddy: komodo.in.hypyr.space
    caddy.forward_auth: http://authentik-server:9000
    caddy.forward_auth.uri: /outpost.goauthentik.io/auth/caddy
    caddy.forward_auth.copy_headers: X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid
    caddy.reverse_proxy: "{{upstreams 30160}}"
    caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"
```

If your controller does not support these keys, use Template B.

## Template B: Numbered blocks

```yaml
deploy:
  labels:
    caddy_10: komodo.in.hypyr.space
    caddy_10.forward_auth: http://authentik-server:9000
    caddy_10.forward_auth.uri: /outpost.goauthentik.io/auth/caddy
    caddy_10.forward_auth.copy_headers: X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid
    caddy_10.reverse_proxy: "{{upstreams 30160}}"
    caddy_10.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"
```

## Authentik Side: Blueprint (required)

Caddy labels alone are not enough. Authentik must know about the application.
Create a blueprint in `stacks/platform/auth/authentik/blueprints/`:

```yaml
# stacks/platform/auth/authentik/blueprints/forward-auth-myservice.yaml
# yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
version: 1

metadata:
  name: "Forward Auth - My Service"
  labels:
    blueprints.goauthentik.io/instantiate: "true"

entries:
  # 1. Proxy Provider
  - model: authentik_providers_proxy.proxyprovider
    state: present
    id: myservice-provider
    identifiers:
      name: "myservice-forward-auth"
    attrs:
      name: "myservice-forward-auth"
      mode: "forward_single"
      external_host: "https://myservice.in.hypyr.space"
      access_token_validity: "hours=24"
      refresh_token_validity: "days=30"
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]

  # 2. Application
  - model: authentik_core.application
    state: present
    identifiers:
      slug: "myservice"
    attrs:
      name: "My Service"
      slug: "myservice"
      meta_launch_url: "https://myservice.in.hypyr.space"
      policy_engine_mode: "any"
      provider: !KeyOf myservice-provider

  # 3. Assign to embedded outpost
  - model: authentik_outposts.outpost
    state: present
    identifiers:
      name: "authentik Embedded Outpost"
    attrs:
      name: "authentik Embedded Outpost"
      type: "proxy"
      providers:
        - !KeyOf myservice-provider
```

Blueprints are auto-applied within 60 minutes. To apply immediately, go to
Admin > Customization > Blueprints and click Apply.

See `stacks/platform/auth/authentik/blueprints/forward-auth-grafana.yaml` for a working example.

## Checklist: Protecting a New Service

1. Create Authentik blueprint in `stacks/platform/auth/authentik/blueprints/forward-auth-<service>.yaml`
2. Set `instantiate: "true"` when ready to activate
3. Add Caddy forward_auth labels to the service's compose file (Template A or B above)
4. Ensure the service is on `proxy_network`
5. Redeploy both the authentik stack and the service stack via Komodo

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
