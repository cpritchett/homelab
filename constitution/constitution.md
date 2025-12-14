# Homelab Infrastructure Constitution
**Domain:** hypyr.space  
**Effective:** 2025-12-14

## Purpose
This constitution defines immutable principles governing networking, DNS intent, external ingress, and management access.

If a change conflicts with this constitution, the change is invalid unless the constitution itself is amended.

## Principles
1. **Management is Sacred and Boring**  
   The management network remains isolated, predictable, and minimally reachable.

2. **DNS Encodes Intent**  
   Names describe trust boundaries. Public and internal services do not share identical names.

3. **External Access is Identity-Gated**  
   External access is mediated by Cloudflare Tunnel + Access, not WAN exposure.

4. **Routing Does Not Imply Permission**  
   Reachability does not grant authorization; policy boundaries remain authoritative.

5. **Prefer Structural Safety Over Convention**  
   Make unsafe actions hard; avoid relying on memory, tribal knowledge, or "we'll be careful."
