# DNS Checks

Validation checklist for DNS compliance.

## Manual / CI Checks

- [ ] No new suffixes like `.lan`, `.local`, `.home` added anywhere
- [ ] Public hostnames use `*.hypyr.space`
- [ ] Internal-only hostnames use `*.in.hypyr.space`
- [ ] No internal DNS overrides of public FQDNs to bypass Access
- [ ] ExternalDNS `external` policy targets only `hypyr.space` zone
- [ ] ExternalDNS `internal` policy targets only `in.hypyr.space` zone
- [ ] Services with `external` policy have corresponding Cloudflare Tunnel configuration
- [ ] Unifi Fiber Gateway is authoritative for `in.hypyr.space` zone
