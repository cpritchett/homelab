# Bootstrap Values

Place per-release override files here (referenced by `bootstrap/helmfile.d/01-apps.yaml`).  
Use `op inject` when applying to render secrets from 1Password, e.g.:

```bash
op inject -i bootstrap/values/onepassword-store.yaml | kubectl apply -f -
```

Typical files:
- `cilium.yaml`, `coredns.yaml`, `spegel.yaml`, `cert-manager.yaml`
- `external-secrets.yaml`
- `onepassword-store.yaml` (requires connect credentials, keep `installed: false` until provided)
- `kube-vip.yaml` (control-plane VIP only)
- `flux-operator.yaml`, `flux-instance.yaml` (Flux repo now `https://github.com/cpritchett/homelab`, path placeholder `./kubernetes/clusters/homelab/flux`)

Missing files will warn (helmfile `missingFileHandler: Warn`), but some releases will fail without required values.
