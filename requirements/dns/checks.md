# DNS Checks

Validation checklist for DNS compliance.

## Manual / CI Checks

- [ ] No new suffixes like `.lan`, `.local`, `.home` added anywhere
- [ ] Public hostnames use `*.hypyr.space`
- [ ] Internal-only hostnames use `*.in.hypyr.space`
- [ ] No internal DNS overrides of public FQDNs to bypass Access
